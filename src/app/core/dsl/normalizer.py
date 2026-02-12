import ast
import re

from lark import Token, Transformer, Tree

from app.core.dsl.errors import ValidationError
from app.core.dsl.printer import MinimalPrinter


class DSLNormalizer(Transformer):
    def __init__(self):
        super().__init__()
        self.errors = []
        self.field_types = {
            "amount": "number",
            "currency": "string",
            "merchantId": "string",
            "ipAddress": "string",
            "deviceId": "string",
            "user.age": "number",
            "user.region": "string",
        }
        self.operators = [">=", "<=", "!=", ">", "<", "=", "AND", "OR", "NOT"]

    def _normalize_keywords(self, expr: str) -> str:
        expr = re.sub(r"\b(and)\b", "AND", expr, flags=re.I)
        expr = re.sub(r"\b(or)\b", "OR", expr, flags=re.I)
        expr = re.sub(r"\b(not)\b", "NOT ", expr, flags=re.I)
        expr = re.sub(r"\s+", " ", expr)
        return expr.strip()

    def _normalize_operators(self, expr: str) -> str:
        ops = sorted(self.operators, key=len, reverse=True)
        pattern = "|".join(re.escape(op) for op in ops)
        expr = re.sub(rf"({pattern})", r" \1 ", expr)
        expr = re.sub(r"\s+", " ", expr)
        return expr.strip()

    def _to_python(self, expr: str) -> str:
        expr = re.sub(r" = ", " == ", expr)  # noqa: RUF055
        expr = expr.replace("AND", "and")
        expr = expr.replace("OR", "or")
        expr = expr.replace("NOT", "not")
        return expr

    def _remove_redundant_parentheses(self, expr: str) -> str:
        sanitized = expr.replace("user.age", "user_age").replace("user.region", "user_region")
        py_expr = self._to_python(sanitized)
        try:
            tree = ast.parse(py_expr, mode="eval")
            printer = MinimalPrinter()
            minimal = printer.visit(tree.body, 0)
            minimal = minimal.replace("user_age", "user.age").replace("user_region", "user.region")
            return minimal
        except (SyntaxError, ValueError):
            return expr

    def _to_str(self, item):
        if isinstance(item, Token):
            return item.value
        if isinstance(item, Tree):
            return str(item)
        return str(item)

    def field(self, items):
        return items[0].value

    def operator(self, items):
        return items[0].value

    def number(self, items):
        return {"type": "number", "value": items[0].value}

    def string(self, items):
        token_val = items[0].value
        return {"type": "string", "value": token_val[1:-1]}

    def comparison(self, items):
        field, op, value = items
        field_type = self.field_types.get(field, "unknown")
        value_type = value["type"]

        if field_type == "unknown":
            self.errors.append(
                ValidationError(
                    code="DSL_INVALID_FIELD",
                    message=f"Неизвестное поле DSL '{field}'",
                )
            )
        else:
            if field_type == "string" and op not in ("=", "!="):
                self.errors.append(
                    ValidationError(
                        code="DSL_INVALID_OPERATOR",
                        message=f"Оператор '{op}' нельзя применить к строковому полю '{field}'",
                    )
                )

            if field_type != value_type:
                self.errors.append(
                    ValidationError(
                        code="DSL_INVALID_OPERATOR",
                        message=f"Тип значения ({value_type}) не соответствует типу поля '{field}' ({field_type})",
                    )
                )

        val_str = f"'{value['value']}'" if value_type == "string" else value["value"]
        return f"{field} {op} {val_str}"

    def paren_expr(self, items):
        inner = self._to_str(items[0])
        return f"({inner})"

    def atom(self, items):
        return items[0]

    def not_operation(self, items):
        child_str = self._to_str(items[0])
        if child_str.startswith("("):
            return f"NOT {child_str}"
        if " AND " in child_str or " OR " in child_str:
            return f"NOT ({child_str})"
        return f"NOT {child_str}"

    def not_expr(self, items):
        return items[0]

    def and_expr(self, items):
        operands = []
        for item in items:
            if isinstance(item, Token):
                continue
            operands.append(self._to_str(item))
        if len(operands) == 1:
            return operands[0]
        return " AND ".join(operands)

    def or_expr(self, items):
        operands = []
        for item in items:
            if isinstance(item, Token):
                continue
            operands.append(self._to_str(item))
        if len(operands) == 1:
            return operands[0]
        return " OR ".join(operands)

    def expression(self, items):
        return items[0]

    def start(self, items):
        return items[0]
