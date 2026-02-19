from pydantic import ValidationError

from app.core.exceptions.base import DuplicateError
from app.core.exceptions.event_exs import EventAlreadyExistsError, EventNotFoundError
from app.core.schemas.event import (
    EventBatchBody,
    EventBatchResponse,
    EventCreateBody,
    EventErrorDetail,
    EventReadResponse,
    SendEventData,
)
from app.core.schemas.user import TokenData
from app.core.utils.paginated import Page, PaginationParams
from app.infrastructure.models import Event, EventCatalog
from app.infrastructure.unit_of_work import UnitOfWork


class EventService:
    def __init__(self, uow: UnitOfWork):
        self.uow = uow

    @staticmethod
    def _format_validation_error(e: ValidationError) -> str:
        errors = []
        for err in e.errors():
            field = " -> ".join(str(loc) for loc in err["loc"])
            msg = err["msg"]
            errors.append(f"{field}: {msg}" if field else msg)
        return "; ".join(errors)

    async def create(self, user_data: TokenData, event_data: EventCreateBody) -> EventReadResponse:
        async with self.uow:
            try:
                metric = await self.uow.event_repo.add(EventCatalog(**event_data.model_dump(),
                                                                      createdBy=user_data.id))
                return EventReadResponse(**metric.model_dump())
            except DuplicateError:
                raise EventAlreadyExistsError from DuplicateError

    async def get_all_catalog_events(self, pagination: PaginationParams) -> Page[EventReadResponse]:
        async with self.uow:
            events = await self.uow.event_repo.get_paginated(offset=pagination.offset, limit=pagination.limit)
            valid = [EventReadResponse(**u.model_dump()) for u in events]
            total = await self.uow.event_repo.count()
            return Page.build(items=valid, total=total, pagination=pagination)

    async def get_by_code(self, code: str) -> EventReadResponse | None:
        async with self.uow:
            event_exists = await self.uow.event_repo.get_by_code(code)
            if not event_exists:
                raise EventNotFoundError

            return EventReadResponse(**event_exists.model_dump())

    async def send_batch(self, batch: EventBatchBody) -> EventBatchResponse:
        exceptions: list[EventErrorDetail] = []
        duplicates = 0
        accepted = 0

        async with self.uow:
            for i, raw in enumerate(batch.events):
                event_key = raw.get("eventKey", f"index:{i}")
                try:
                    item = SendEventData.model_validate(raw)
                except ValidationError as e:
                    exceptions.append(EventErrorDetail(
                        eventKey=event_key,
                        reason=self._format_validation_error(e),
                    ))
                    continue

                try:
                    async with self.uow.session.begin_nested():
                        await self.uow.event_repo.assign_event(Event(**item.model_dump()))
                    accepted += 1
                except DuplicateError:
                    duplicates += 1
                except Exception as ex:
                    exceptions.append(EventErrorDetail(
                        eventKey=item.eventKey,
                        reason=str(ex),
                    ))

        return EventBatchResponse(
            accepted=accepted,
            duplicates=duplicates,
            rejected=len(exceptions),
            total=len(batch.events),
            errors=exceptions,
        )
