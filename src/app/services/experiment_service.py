import random
from collections.abc import Awaitable, Callable
from uuid import UUID

from app.core.exceptions.base import DuplicateError
from app.core.exceptions.experiment_exs import (
    ExperimentAlreadyExistsError,
    ExperimentInvalidStatusError,
    ExperimentNotFoundError,
    VersionOfExperimentAlreadyExistsError,
)
from app.core.exceptions.flag_exs import FlagNotFoundError
from app.core.schemas.decision import DecisionBody, DecisionData, DecisionResponse
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
from app.infrastructure.models import Decision, Experiment, Variant
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

    async def _generate_decisions(self, experiment_id: UUID) -> list[Decision]:
        secure_random = random.SystemRandom()
        async with self.uow:
            experiment = await self.uow.experiment_repo.get_by_id_with_variants(experiment_id)
            if not experiment:
                raise ExperimentNotFoundError

            users = await self.uow.user_repo.get_all()
            if not users:
                return []

            total_users = len(users)
            participants_count = int(total_users * experiment.part / 100)

            if participants_count == 0:
                return []

            weights = [user.exp_index for user in users]
            participating_users = secure_random.choices(
                users,
                weights=weights,
                k=participants_count
            )

            variants = list(experiment.variants)
            variant_pool: list[Variant] = []
            for variant in variants:
                variant_pool.extend([variant] * variant.weight)

            decisions: list[Decision] = []
            for i, user in enumerate(participating_users):
                selected_variant = variant_pool[i % len(variant_pool)]

                existing = await self.uow.decision_repo.get_by_user_and_flag(
                    user.id,
                    experiment.flag_code
                )
                if not existing:
                    decision = Decision(
                        user_id=user.id,
                        variant_id=selected_variant.id,
                        isRequested=False,
                        user=user,
                        variant=selected_variant,
                    )
                    decisions.append(decision)
        return decisions

    async def create(self, user_data: TokenData, experiment_data: ExperimentCreateBody) -> ExperimentReadResponse:
        async with self.uow:
            flag = await self.uow.flag_repo.get_by_code(experiment_data.flag_code)
            if not flag:
                raise FlagNotFoundError

            try:
                experiment = await self.uow.experiment_repo.add(
                    Experiment(**experiment_data.model_dump(exclude={"variants"}), createdBy=user_data.id))
            except DuplicateError as e:
                raise VersionOfExperimentAlreadyExistsError from e

            added_variants: list[VariantData] = []
            for variant_data in experiment_data.variants:
                variant = await self.uow.experiment_repo.add_variant(
                    Variant(**variant_data.model_dump(), experiment_id=experiment.id))
                added_variants.append(VariantData(**variant.model_dump()))
            return ExperimentReadResponse(**experiment.model_dump(), variants=added_variants)

    async def create_new(self, user_data: TokenData, experiment_data: ExperimentCreateBody) -> ExperimentReadResponse:
        async with self.uow:
            experiment = await self.uow.experiment_repo.get_by_code(experiment_data.code)
            if experiment:
                raise ExperimentAlreadyExistsError
        return await self.create(user_data, experiment_data)

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

    async def get_by_code(self, code: str, version: float | None = None) -> ExperimentReadResponse:
        async with self.uow:
            experiment = await self._get_experiment_or_404(lambda: self.uow.experiment_repo.get_by_code(code, version))
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
                raise ExperimentInvalidStatusError

        result = await self.create(user_data, ExperimentCreateBody(
            **data.model_dump(), code=experiment.code, flag_code=experiment.flag_code))
        _ = await self.uow.experiment_repo.update(experiment.id, ExperimentUpdate(isCurrent=False))
        return result

    async def set_status(self, code: str,
                         status: ExperimentStatus, old: set[ExperimentStatus]) -> ExperimentReadResponse:
        async with self.uow:
            experiment = await self.uow.experiment_repo.get_by_code(code)
            if not experiment:
                raise ExperimentNotFoundError

            if experiment.status in old:
                await self.uow.experiment_repo.set_status(experiment.id, status)
                return ExperimentReadResponse(**experiment.model_dump(exclude={"status"}),
                                              status=status,
                                              variants=[VariantData(**exp.model_dump()) for exp in experiment.variants])
            raise ExperimentInvalidStatusError

    async def set_status_review(self, code: str) -> ExperimentReadResponse:
        # exp = await self.get_by_code(code)
        # decisions = await self._generate_decisions(exp.id)
        return await self.set_status(code, ExperimentStatus.IN_REVIEW, {ExperimentStatus.DRAFT})

    async def set_status_draft(self, code: str) -> ExperimentReadResponse:
        return await self.set_status(code, ExperimentStatus.DRAFT, {ExperimentStatus.REJECTED})

    async def get_decisions(self, data: DecisionBody) -> DecisionResponse:
        decisions: list[DecisionData] = []
        user_id = data.user_id

        async with self.uow:
            for code in data.flag_codes:
                result = await self.uow.decision_repo.get_by_user_and_flag(user_id, code)
                if not result:
                    flag = await self.uow.flag_repo.get_by_code(code)
                    decisions.append(DecisionData(user_id=user_id, flag_code=code, value=flag.default))
                    continue
                decisions.append(DecisionData(
                    user_id=user_id,
                    flag_code=code,
                    experiment_code=result.variant.experiment.code,
                    variant=VariantData(**result.variant.model_dump()),
                    decision_id=result.id,
                    value=result.variant.value
                ))
        return DecisionResponse(items=decisions)
