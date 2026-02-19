from uuid import UUID

from app.core.exceptions.base import DuplicateError
from app.core.exceptions.event_exs import EventAlreadyExistsError, EventNotFoundError
from app.core.schemas.event import EventCreateBody, EventReadResponse
from app.core.schemas.user import TokenData
from app.core.utils.paginated import Page, PaginationParams
from app.infrastructure.models import EventCatalog
from app.infrastructure.unit_of_work import UnitOfWork


class EventService:
    def __init__(self, uow: UnitOfWork):
        self.uow = uow

    async def create(self, user_data: TokenData, event_data: EventCreateBody) -> EventReadResponse:
        async with self.uow:
            try:
                metric_codes = event_data.metric_codes
                data = event_data.model_dump(exclude={"metric_codes"})

                event = EventCatalog(**data, createdBy=user_data.id)
                event = await self.uow.event_repo.add(event)

                if metric_codes:
                    metrics = await self.uow.metric_repo.get_by_codes(metric_codes)
                    event = await self.uow.event_repo.get_by_code_with_metrics(event.code)
                    event.metrics = metrics

                return EventReadResponse(**event.model_dump())
            except DuplicateError:
                raise EventAlreadyExistsError from DuplicateError

    async def get_all_catalog_events(self, pagination: PaginationParams) -> Page[EventReadResponse]:
        async with self.uow:
            events = await self.uow.event_repo.get_paginated(offset=pagination.offset, limit=pagination.limit)
            valid = [EventReadResponse(**u.model_dump()) for u in events]
            total = await self.uow.event_repo.count()
            return Page.build(items=valid, total=total, pagination=pagination)

    async def get_by_code(self, code: str) -> EventReadResponse:
        async with self.uow:
            event = await self.uow.event_repo.get_by_code_with_metrics(code)
            if not event:
                raise EventNotFoundError

            return EventReadResponse(**event.model_dump())
