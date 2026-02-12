from lark import Lark, Tree


class DSLEvaluator:
    def __init__(self, grammar: str):
        self.grammar = grammar

    def evaluate(self, expression: str, transaction: dict, user: dict | None = None) -> bool:
        try:
            parser = Lark(self.grammar, start="start", parser="lalr")
            tree = parser.parse(expression)
            return self._eval_tree(tree, transaction, user or {})
        except Exception:
            return False

    def _eval_tree(self, tree: Tree, transaction: dict, user: dict) -> bool:
        if tree.data == "start" or tree.data == "expression":
            return self._eval_tree(tree.children[0], transaction, user)

        if tree.data == "or_expr":
            results = [self._eval_tree(child, transaction, user) for child in tree.children if hasattr(child, "data")]
            return any(results)

        if tree.data == "and_expr":
            results = [self._eval_tree(child, transaction, user) for child in tree.children if hasattr(child, "data")]
            return all(results)

        if tree.data == "not_operation":
            return not self._eval_tree(tree.children[0], transaction, user)

        if tree.data == "not_expr" or tree.data == "atom":
            return self._eval_tree(tree.children[0], transaction, user)

        if tree.data == "comparison":
            field_node = tree.children[0]
            op_node = tree.children[1]
            value_node = tree.children[2]

            field_name = field_node.children[0].value
            operator = op_node.children[0].value

            if field_name.startswith("user."):
                field_key = field_name.split(".")[1]
                field_value = user.get(field_key)
            else:
                field_value = transaction.get(field_name)

            if field_value is None:
                return False

            if value_node.data == "number":
                compare_value = float(value_node.children[0].value)
            else:
                compare_value = value_node.children[0].value[1:-1]

            return self._compare(field_value, operator, compare_value)

        return False

    @staticmethod
    def _compare(field_val, op, compare_val):
        if op == "=":
            return field_val == compare_val
        if op == "!=":
            return field_val != compare_val
        if op == ">":
            return field_val > compare_val
        if op == ">=":
            return field_val >= compare_val
        if op == "<":
            return field_val < compare_val
        if op == "<=":
            return field_val <= compare_val
        return False
