from uuid import UUID

from app.core.exceptions.base import DuplicateError
from app.core.exceptions.experiment_exs import ExperimentInvalidStatusError, ExperimentNotFoundError
from app.core.exceptions.review_exs import ReviewAlreadyExistsError, ReviewNotFoundError
from app.core.exceptions.user_exs import ForbiddenError
from app.core.schemas.experiment import ExperimentStatus
from app.core.schemas.review import ReviewCreateBody, ReviewDataResponse
from app.core.schemas.user import TokenData
from app.infrastructure.models import Review
from app.infrastructure.unit_of_work import UnitOfWork


class ReviewService:
    def __init__(self, uow: UnitOfWork):
        self.uow = uow

    # TODO: fallback и переход в статут из ревью
    async def create(self, user_data: TokenData, review_data: ReviewCreateBody) -> ReviewDataResponse:
        async with self.uow:
            try:
                experiment = await self.uow.experiment_repo.get_by_id(review_data.experiment_id)
                if experiment is None:
                    raise ExperimentNotFoundError
                if experiment.status != ExperimentStatus.IN_REVIEW:
                    raise ExperimentInvalidStatusError
                approver = await self.uow.approver_repo.get_by_two_ids(experiment.createdBy, user_data.id)
                if not approver:
                    raise ForbiddenError

                review = await self.uow.review_repo.add(Review(**review_data.model_dump(), approvedBy=approver.id))
                return ReviewDataResponse(**review.model_dump())
            except DuplicateError:
                raise ReviewAlreadyExistsError from DuplicateError

    async def get_by_id(self, review_id: UUID) -> ReviewDataResponse | None:
        async with self.uow:
            review_exists = await self.uow.review_repo.get_by_id(review_id)
            if not review_exists:
                raise ReviewNotFoundError

            return ReviewDataResponse(**review_exists.model_dump())
