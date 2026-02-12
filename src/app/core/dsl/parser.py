from lark import Lark, LarkError, UnexpectedCharacters, UnexpectedInput

from app.core.dsl.errors import ValidationError, ValidationResult
from app.core.dsl.normalizer import DSLNormalizer


class DSLParser:
    def __init__(self, normalizer: DSLNormalizer, grammar: str):
        self.parser = Lark(grammar, start="start", parser="lalr")
        self.normalizer = normalizer

    def validate(self, expression: str) -> ValidationResult:
        expression = self.normalizer._normalize_keywords(expression)
        expression = self.normalizer._normalize_operators(expression)
        try:
            tree = self.parser.parse(expression)
            self.normalizer.errors = []
            rebuilt = self.normalizer.transform(tree)
            if self.normalizer.errors:
                return ValidationResult(is_valid=False, normalized_expression=None, errors=self.normalizer.errors)

            normalized = self.normalizer._remove_redundant_parentheses(str(rebuilt))
            return ValidationResult(is_valid=True, normalized_expression=normalized, errors=[])

        except UnexpectedInput as e:
            context = expression[max(0, e.pos_in_stream - 5) : e.pos_in_stream + 5]
            expected_list = list(e.expected) if hasattr(e, "expected") else []

            return ValidationResult(
                is_valid=False,
                normalized_expression=None,
                errors=[
                    ValidationError(
                        code="DSL_PARSE_ERROR",
                        message=f"Неожиданный символ: ожидалось {', '.join(expected_list)}"
                        if expected_list
                        else "Синтаксическая ошибка",
                        position=e.pos_in_stream,
                        near=context,
                    )
                ],
            )

        except (UnexpectedCharacters, LarkError) as e:
            return ValidationResult(
                is_valid=False,
                normalized_expression=None,
                errors=[ValidationError(code="DSL_PARSE_ERROR", message=str(e), position=0, near=expression[:20])],
            )
