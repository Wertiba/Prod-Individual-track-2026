DSL_GRAMMAR = r"""
    start: expression
    expression: or_expr
    or_expr: and_expr (OR and_expr)*
    and_expr: not_expr (AND not_expr)*
    not_expr: NOT not_expr -> not_operation
            | atom
    atom: comparison
        | paren_expr
    paren_expr: "(" expression ")"
    comparison: field operator value
    field: FIELD_NAME
    operator: OP
    value: NUMBER -> number
         | STRING -> string

    FIELD_NAME: "amount" | "currency" | "merchantId" | "ipAddress" | "deviceId" | "user.age" | "user.region"
    OP: ">" | ">=" | "<" | "<=" | "=" | "!="
    STRING: "'" /[^']*/ "'"
    NUMBER: /\d+(\.\d+)?/
    AND: "and"i
    OR: "or"i
    NOT: "not"i
    %import common.WS
    %ignore WS
"""
