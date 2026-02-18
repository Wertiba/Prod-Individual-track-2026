from collections.abc import Awaitable, Callable
from uuid import UUID

from app.core.exceptions.base import DuplicateError, UnprocessableEntityError
from app.core.exceptions.experiment_exs import ExperimentAlreadyExistsError, ExperimentNotFoundError
from app.core.exceptions.flag_exs import FlagNotFoundError
from app.core.schemas.experiment import (
    ExperimentCreateBody,
    ExperimentHistoryResponse,
    ExperimentReadResponse,
    ExperimentStatus,
    ExperimentUpdate,
    ExperimentUpdateBody,
    VariantData,
)
from app.core.schemas.user import TokenData
from app.core.utils.paginated import Page, PaginationParams
from app.infrastructure.models import Experiment, Variant
from app.infrastructure.unit_of_work import UnitOfWork


class ExperimentService:
    def __init__(self, uow: UnitOfWork):
        self.uow = uow

    @staticmethod
    def _convert_to_response(experiment: Experiment) -> ExperimentReadResponse:
        variants = [VariantData(**v.model_dump()) for v in experiment.variants]
        return ExperimentReadResponse(
            **experiment.model_dump(),
            variants=variants
        )

    @staticmethod
    async def _get_experiment_or_404(getter: Callable[[], Awaitable[Experiment | None]]) -> Experiment:
        experiment = await getter()
        if not experiment:
            raise ExperimentNotFoundError
        return experiment

    async def create(self, user_data: TokenData, experiment_data: ExperimentCreateBody) -> ExperimentReadResponse:
        async with self.uow:
            try:
                flag = await self.uow.flag_repo.get_by_code(experiment_data.flag_code)
                if not flag:
                    raise FlagNotFoundError

                experiment = await self.uow.experiment_repo.add(
                    Experiment(**experiment_data.model_dump(exclude={"variants"}), createdBy=user_data.id))
            except DuplicateError:
                raise ExperimentAlreadyExistsError from DuplicateError

            added_variants: list[VariantData] = []
            for variant_data in experiment_data.variants:
                variant = await self.uow.experiment_repo.add_variant(
                    Variant(**variant_data.model_dump(), experiment_id=experiment.id))
                added_variants.append(VariantData(**variant.model_dump()))
            return ExperimentReadResponse(**experiment.model_dump(), variants=added_variants)

    async def get_all_experiments(self, pagination: PaginationParams) -> Page[ExperimentReadResponse]:
        async with self.uow:
            experiments = await self.uow.experiment_repo.get_paginated_with_variants(
                offset=pagination.offset,
                limit=pagination.limit
            )
            valid = [self._convert_to_response(e) for e in experiments]
            total = await self.uow.experiment_repo.count()
            return Page.build(items=valid, total=total, pagination=pagination)

    async def get_by_id(self, experiment_id: UUID) -> ExperimentReadResponse:
        async with self.uow:
            experiment = await self._get_experiment_or_404(
                lambda: self.uow.experiment_repo.get_by_id_with_variants(experiment_id)
            )
            return self._convert_to_response(experiment)

    async def get_by_code(self, code: str) -> ExperimentReadResponse:
        async with self.uow:
            experiment = await self._get_experiment_or_404(lambda: self.uow.experiment_repo.get_by_code(code))
            return self._convert_to_response(experiment)

    async def get_history(self, code: str) -> ExperimentHistoryResponse:
        async with self.uow:
            experiments = await self.uow.experiment_repo.get_history(code)
            if not experiments:
                raise ExperimentNotFoundError
            return ExperimentHistoryResponse(versions=[self._convert_to_response(ex) for ex in experiments])

    async def update(self, code: str, user_data: TokenData, data: ExperimentUpdateBody) -> ExperimentReadResponse:
        async with self.uow:
            experiment = await self.uow.experiment_repo.get_by_code(code)
            if not experiment:
                raise ExperimentNotFoundError
            if not experiment.status == ExperimentStatus.DRAFT:
                raise UnprocessableEntityError
            experiment = await self.uow.experiment_repo.update(experiment.id, ExperimentUpdate(isCurrent=False))

        return await self.create(user_data, ExperimentCreateBody(
            **data.model_dump(), code=experiment.code, flag_code=experiment.flag_code))

    async def set_status(self, code: str,
                         status: ExperimentStatus, old: set[ExperimentStatus]) -> ExperimentReadResponse:
        async with self.uow:
            experiment = await self.uow.experiment_repo.get_by_code(code)
            if experiment and experiment.status in old:
                await self.uow.experiment_repo.set_status(experiment.id, status)
                return ExperimentReadResponse(**experiment.model_dump(exclude={"status"}), status=status)
            raise UnprocessableEntityError

    async def set_status_review(self, code: str) -> ExperimentReadResponse:
        return await self.set_status(code, ExperimentStatus.IN_REVIEW, {ExperimentStatus.DRAFT})
