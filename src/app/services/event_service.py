from datetime import UTC, datetime, timedelta
from uuid import UUID

from pydantic import ValidationError

from app.core.exceptions.base import DuplicateError, RelationNotFoundError
from app.core.exceptions.event_exs import EventAlreadyExistsError, EventNotFoundError
from app.core.exceptions.experiment_exs import ExperimentInvalidStatusError, ExperimentNotFoundError
from app.core.schemas.event import (
    EventBatchBody,
    EventBatchResponse,
    EventCreateBody,
    EventErrorDetail,
    EventReadResponse,
    SendEventData,
)
from app.core.schemas.experiment import ExperimentStatus
from app.core.schemas.metric import AggregationUnit, GuardrailAction, MetricType
from app.core.schemas.reports import ExperimentReportResponse, MetricReportItem, VariantReportItem
from app.core.schemas.user import TokenData
from app.core.utils.paginated import Page, PaginationParams
from app.infrastructure.models import Event, EventCatalog, GuardrailHistory, Metric, MetricCatalog
from app.infrastructure.models.event import EventMetricLink
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

    @staticmethod
    def _calculate(catalog: MetricCatalog, links: list[EventMetricLink], events: list[Event]) -> float:
        if not events:
            return 0.0

        match catalog.type:
            case MetricType.COUNT:
                if catalog.aggregationUnit == AggregationUnit.USER:
                    return float(len({e.decision_id for e in events}))
                return float(len(events))

            case MetricType.SUM:
                link = links[0]
                field = link.value_field or "value"
                return float(sum(e.data.get(field, 0) for e in events if e.data))

            case MetricType.AVG:
                link = links[0]
                field = link.value_field or "value"
                values = [e.data.get(field, 0) for e in events if e.data]
                return sum(values) / len(values) if values else 0.0

            case MetricType.MIN:
                link = links[0]
                field = link.value_field or "value"
                values = [e.data.get(field) for e in events if e.data and e.data.get(field) is not None]
                return float(min(values)) if values else 0.0

            case MetricType.MAX:
                link = links[0]
                field = link.value_field or "value"
                values = [e.data.get(field) for e in events if e.data and e.data.get(field) is not None]
                return float(max(values)) if values else 0.0

            case MetricType.RATIO:
                numerator_codes = {l.eventCatalog_code for l in links if l.role == "numerator"}
                denominator_codes = {l.eventCatalog_code for l in links if l.role == "denominator"}
                n = sum(1 for e in events if e.eventCatalog_code in numerator_codes)
                d = sum(1 for e in events if e.eventCatalog_code in denominator_codes)
                return n / d if d else 0.0

            case _:
                return 0.0

    async def _check_guardrails(self, experiment_id: UUID) -> None:
        guardrails = await self.uow.metric_repo.get_guardrails(experiment_id)
        if not guardrails:
            return

        for guardrail in guardrails:
            links = await self.uow.metric_repo.get_event_metric_link(guardrail.metricCatalog_code)
            if not links:
                continue

            event_codes = [l.eventCatalog_code for l in links]
            time_from = datetime.now(tz=UTC) - timedelta(seconds=guardrail.window or 864000)

            events = await self.uow.event_repo.get_by_experiment_and_event_codes(
                experiment_id=experiment_id,
                event_codes=event_codes,
                time_from=time_from,
            )

            value = self._calculate(guardrail.metric_catalog, links, events)

            if guardrail.threshold is not None and value >= guardrail.threshold:
                await self._trigger_guardrail(guardrail, value, experiment_id)

    async def _trigger_guardrail(self, guardrail: Metric, actual_value: float, experiment_id: UUID) -> None:
        if guardrail.action_code == GuardrailAction.PAUSE:
            await self._pause_experiment(experiment_id)
        elif guardrail.action_code == GuardrailAction.ROLLBACK:
            await self._rollback_experiment(experiment_id)

        await self.uow.metric_repo.add_history(GuardrailHistory(
            metric_id=guardrail.id,
            history={
                "metric_code": guardrail.metricCatalog_code,
                "threshold": guardrail.threshold,
                "actual_value": actual_value,
                "action": guardrail.action_code,
                "window": guardrail.window,
                "triggered_at": datetime.now(tz=UTC).isoformat(),
            }
        ))

    async def _pause_experiment(self, experiment_id: UUID) -> None:
        experiment = await self.uow.experiment_repo.get_by_id(experiment_id)
        if not experiment:
            return
        if experiment.status != ExperimentStatus.RUNNING:
            return
        experiment.status = ExperimentStatus.PAUSED

    async def _rollback_experiment(self, experiment_id: UUID) -> None:
        experiment = await self.uow.experiment_repo.get_by_id_with_variants(experiment_id)
        if not experiment:
            return
        if experiment.status != ExperimentStatus.RUNNING:
            return

        control_variant = next(
            (v for v in experiment.variants if v.isControl),
            None
        )

        decisions = await self.uow.decision_repo.get_by_experiment(experiment_id)
        for decision in decisions:
            if decision.variant_id != control_variant.id:
                decision.variant_id = control_variant.id

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

    async def process_batch(self, batch: EventBatchBody) -> EventBatchResponse:
        exceptions: list[EventErrorDetail] = []
        duplicates = 0
        default = 0
        accepted = 0
        affected_experiment_ids: set[UUID] = set()

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
                    decision = await self.uow.decision_repo.get_by_id_with_variant(item.decision_id)
                    if decision:
                        affected_experiment_ids.add(decision.variant.experiment_id)
                        async with self.uow.session.begin_nested():
                            await self.uow.event_repo.assign_event(Event(**item.model_dump()))
                            accepted += 1
                    else:
                        default += 1

                except DuplicateError:
                    duplicates += 1
                    continue
                except RelationNotFoundError as ex:
                    exceptions.append(EventErrorDetail(
                        eventKey=item.eventKey,
                        reason=str(ex),
                    ))
                    continue
                except Exception as ex:
                    exceptions.append(EventErrorDetail(
                        eventKey=item.eventKey,
                        reason=str(ex),
                    ))
                    continue

            for experiment_id in affected_experiment_ids:
                await self._check_guardrails(experiment_id)

        return EventBatchResponse(
            accepted=accepted,
            duplicates=duplicates,
            rejected=len(exceptions),
            total=len(batch.events),
            errors=exceptions,
        )

    async def get_report(
            self,
            experiment_code: str,
            time_from: datetime,
            time_to: datetime
    ) -> ExperimentReportResponse:
        async with self.uow:
            experiment = await self.uow.experiment_repo.get_by_code(experiment_code)
            if not experiment:
                raise ExperimentNotFoundError
            if experiment.status not in {ExperimentStatus.RUNNING, ExperimentStatus.COMPLETED,
                                         ExperimentStatus.PAUSED, ExperimentStatus.ARCHIVED}:
                raise ExperimentInvalidStatusError

            variants_report = []
            for variant in experiment.variants:
                metrics_report = []
                for metric in experiment.metrics:
                    links = await self.uow.metric_repo.get_event_metric_link(metric.metricCatalog_code)
                    if not links:
                        continue

                    event_codes = [l.eventCatalog_code for l in links]
                    events = await self.uow.event_repo.get_by_variant_and_event_codes(
                        variant_id=variant.id,
                        event_codes=event_codes,
                        time_from=time_from,
                        time_to=time_to,
                    )

                    value = self._calculate(metric.metric_catalog, links, events)
                    metrics_report.append(MetricReportItem(
                        metric_code=metric.metricCatalog_code,
                        metric_name=metric.metric_catalog.name,
                        role=metric.role,
                        value=value,
                        event_count=len(events),
                    ))

                variants_report.append(VariantReportItem(
                    variant_id=variant.id,
                    variant_name=variant.name,
                    is_control=variant.isControl,
                    metrics=metrics_report,
                ))

            return ExperimentReportResponse(
                experiment_code=experiment_code,
                time_from=time_from,
                time_to=time_to,
                variants=variants_report,
            )
