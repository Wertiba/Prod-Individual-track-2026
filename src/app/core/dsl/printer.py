import ast


class MinimalPrinter(ast.NodeVisitor):
    def __init__(self):
        self.prec = {
            ast.Or: 1,
            ast.And: 2,
            ast.Not: 3,
            ast.Compare: 4,
            ast.Constant: 10,
            ast.Name: 10,
        }

    def op_to_str(self, op):
        if isinstance(op, ast.Gt):
            return ">"
        if isinstance(op, ast.GtE):
            return ">="
        if isinstance(op, ast.Lt):
            return "<"
        if isinstance(op, ast.LtE):
            return "<="
        if isinstance(op, ast.Eq):
            return "="
        if isinstance(op, ast.NotEq):
            return "!="
        raise ValueError(f"Unknown op: {type(op)}")

    def visit(self, node, parent_prec=0):
        my_prec = self.prec.get(type(node), 10)
        need_paren = my_prec < parent_prec
        s = self._visit(node)
        if need_paren:
            return f"({s})"
        return s

    def _visit(self, node):
        if isinstance(node, ast.BoolOp):
            op_str = " AND " if isinstance(node.op, ast.And) else " OR "
            return op_str.join(self.visit(v, self.prec[type(node.op)]) for v in node.values)
        elif isinstance(node, ast.UnaryOp):
            if isinstance(node.op, ast.Not):
                return "NOT " + self.visit(node.operand, self.prec[ast.Not])
            raise ValueError(f"Unknown unary op: {type(node.op)}")
        elif isinstance(node, ast.Compare):
            left = self.visit(node.left, 5)
            res = [left]
            for o, cmp in zip(node.ops, node.comparators):  # noqa: B905
                res.append(f" {self.op_to_str(o)} ")  # noqa: FURB113
                res.append(self.visit(cmp, 5))
            return "".join(res)
        elif isinstance(node, ast.Name):
            return node.id
        elif isinstance(node, ast.Constant):
            return repr(node.value)
        raise ValueError(f"Unknown node: {type(node)}")
