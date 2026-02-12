from app.core.dsl.errors import ValidationResult
from app.core.dsl.evaluator import DSLEvaluator
from app.core.dsl.normalizer import DSLNormalizer
from app.core.dsl.parser import DSLParser
from app.infrastructure.models import User


class DSLService:
    def __init__(self, grammar: str):
        self.grammar = grammar
        self.normalizer = DSLNormalizer()
        self.parser = DSLParser(self.normalizer, self.grammar)
        self.evaluator = DSLEvaluator(self.grammar)

    def validate(self, expression: str) -> ValidationResult:
        return self.parser.validate(expression)

    def evaluate(self, expression: str, transaction, user: User) -> bool:
        transaction_data = transaction.model_dump()
        return self.evaluator.evaluate(expression, transaction_data, user.model_dump(exclude={"token_type"}))
