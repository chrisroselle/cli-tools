import sys

if len(sys.argv) == 1:
    sys.stderr.write(f"usage: {sys.argv[0]} <file>")
    exit(1)

with open(sys.argv[1], "r") as file:
    seen = set()
    result = []
    # inefficient, but for this use case it's fine
    for line in reversed(list(file)):
        line = line.rstrip()
        if line not in seen:
            seen.add(line)
            result.append(line)

with open(sys.argv[1], "w") as file:
    for line in reversed(result):
        file.write(line)
        file.write("\n")
