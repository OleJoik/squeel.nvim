import sys
import sqlparse

contents = sys.stdin.read()

result = sqlparse.format

result = sqlparse.format(
    contents,
    keyword_case="upper",
    indentifier_case="lower",
    reindent=True,
    # reindent_aligned=True,
    indent_width=4,
    output_format="sql",
    wrap_after=80,
)

print(result.strip())
