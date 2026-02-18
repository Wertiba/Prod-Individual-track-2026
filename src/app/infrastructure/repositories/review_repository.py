from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.models import Review
from app.infrastructure.repositories.base_repo import BaseRepository


class ReviewRepository(BaseRepository[Review]):
    def __init__(self, session: AsyncSession) -> None:
        super().__init__(session, model=Review)
