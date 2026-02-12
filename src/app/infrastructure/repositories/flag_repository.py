from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.models import Flag
from app.infrastructure.repositories import BaseRepository


class FlagRepository(BaseRepository[Flag]):
    def __init__(self, session: AsyncSession) -> None:
        super().__init__(session, model=Flag)
