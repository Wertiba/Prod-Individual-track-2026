from uuid import UUID

from app.core.exceptions.base import DuplicateError
from app.core.exceptions.experiment_exs import ExperimentAlreadyExistsError, ExperimentNotFoundError
from app.core.exceptions.flag_exs import FlagNotFoundError
from app.core.schemas.experiment import ExperimentCreateBody, ExperimentReadResponse, VariantData
from app.core.schemas.user import TokenData
from app.core.utils.paginated import Page, PaginationParams
from app.infrastructure.models import Experiment, Variant
from app.infrastructure.unit_of_work import UnitOfWork


class ExperimentService:
    def __init__(self, uow: UnitOfWork):
        self.uow = uow

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
                    Variant(**variant_data.model_dump(), experiment_code=experiment_data.code))
                added_variants.append(VariantData(**variant.model_dump()))
            return ExperimentReadResponse(**experiment.model_dump(), variants=added_variants)

    async def get_all_experiments(self, pagination: PaginationParams) -> Page[ExperimentReadResponse]:
        async with self.uow:
            experiments = await self.uow.experiment_repo.get_paginated(offset=pagination.offset, limit=pagination.limit)
            valid = [ExperimentReadResponse(**u.model_dump()) for u in experiments]
            total = await self.uow.experiment_repo.count()
            return Page.build(items=valid, total=total, pagination=pagination)

    async def get_by_id(self, experiment_id: UUID) -> ExperimentReadResponse | None:
        async with self.uow:
            experiment_exists = await self.uow.experiment_repo.get_by_id(experiment_id)
            if not experiment_exists:
                raise ExperimentNotFoundError

            return ExperimentReadResponse(**experiment_exists.model_dump())
