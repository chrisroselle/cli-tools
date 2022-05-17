import argparse
from enum import Enum

import yaml


class GetoptType(Enum):
    FUNCTION = "function"
    SCRIPT = "script"


class UsageType(Enum):
    STANDARD = "standard"
    CASE = "case"


class Option:
    def __init__(self, d):
        # Parse Inputs
        if "long" not in d:
            raise Exception('"long" is required for all options')
        self.long = d["long"]
        self.short = None
        if "short" in d:
            self.short = d["short"]
        self.flag = False
        if "flag" in d:
            self.flag = bool(d["flag"])
        self.required = False
        if "required" in d:
            self.required = bool(d["required"])
        self.description = ""
        if "description" in d:
            self.description = d["description"].replace("$", "\\$")
        self.default = None
        if "default" in d:
            self.default = d["default"]

        # calculate other fields
        self.variable = self.long.replace("-", "_")
        if self.short:
            self.getopt_short = f"{self.short}"
        self.getopt_long = f"{self.long}"
        if self.flag and self.default is True:
            self.getopt_long = f"no-{self.long}"
        if not self.flag:
            self.getopt_short += ":"
            self.getopt_long += ":"
        if self.flag and self.default is True:
            self.ustring = f"--no-{self.long}"
        else:
            self.ustring = f"--{self.long}"
        self.case = self.ustring
        self.ustring_value = f"{self.long.upper()}"
        if self.default:
            self.ustring_value = self.default
        if self.short:
            self.ustring = f"-{self.short},{self.ustring}"
            self.case = f"-{self.short}|{self.case}"
        if not self.flag:
            self.ustring += f"={self.ustring_value}"
        del self.ustring_value
        if not self.required:
            self.ustring = f"[{self.ustring}]"
        if self.description:
            self.usage = (f"  {self.ustring}", self.description)
        else:
            self.usage = (f"  {self.ustring}", "")
        if self.flag:
            if self.default is True:
                self.case = f'{self.case}) {self.variable}="false"; shift ;;'
            else:
                self.case = f'{self.case}) {self.variable}="true"; shift ;;'
        else:
            self.case = f'{self.case}) {self.variable}="$2"; shift 2 ;;'

        del self.ustring


class Positional:
    def __init__(self, d):
        # Parse Inputs
        if "long" not in d:
            raise Exception('"long" is required for positional parameters')
        self.long = d["long"]
        self.required = True
        if "required" in d:
            self.required = bool(d["required"])
        self.multiple = False
        if "multiple_allowed" in d:
            self.multiple = bool(d["multiple_allowed"])
        self.description = ""
        if "description" in d:
            self.description = d["description"]

        # calculate other fields
        self.variable = self.long.replace("-", "_")
        self.ustring = self.long.upper()
        if self.required:
            if self.multiple:
                self.usage = f" {self.ustring} [{self.ustring} ...]"
            else:
                self.usage = f" {self.ustring}"
        else:
            if self.multiple:
                self.usage = f" [{self.ustring} {self.ustring} ...]"
            else:
                self.usage = f" [{self.ustring}]"


parser = argparse.ArgumentParser(
    description="Tool for generating skeleton code for a script or function which uses getopt to parse inputs"
)
parser.add_argument(
    "configuration",
    help="The configuration file that specifies the inputs, in YAML format",
)
args = parser.parse_args()

# getopt parameters
short_options = []
long_options = []

# what will go in usage output
positional_usage = []
required_option_usage = []
optional_option_usage = []

# bash variables
variables = []
variables_with_no_default = []
variables_with_defaults = {}

case_statements = []
validation_statements = []


def p(o, indent=0):
    for line in o.split("\n"):
        print(" " * (indent * 4) + line)


def usage_statement(usage_type):
    if getopt_type is GetoptType.SCRIPT:
        return "usage"
    if getopt_type is GetoptType.FUNCTION:
        if usage_type is UsageType.STANDARD:
            return f"{{ {usage_name}; return 1; }}"
        elif usage_type is UsageType.CASE:
            return f"{usage_name}; return 1"


with open(args.configuration, "r") as cfg_yaml:
    cfg = yaml.safe_load(cfg_yaml)

try:
    getopt_type = GetoptType(cfg["type"])
except ValueError:
    raise Exception(
        f'"{cfg["type"]}" is not a valid type - valid types are: {" ".join([x.value for x in GetoptType])}'
    )

name = cfg["name"]
if getopt_type is GetoptType.SCRIPT and not name.endswith(".sh"):
    name += ".sh"

try:
    description = cfg["description"]
except KeyError:
    description = "This is a placeholder description"

# usage function name
if getopt_type is GetoptType.FUNCTION:
    usage_name = f"_{name}_usage"
    main_name = f"{name}"
if getopt_type is GetoptType.SCRIPT:
    usage_name = "usage"
    main_name = "main"

positional_usage_string = ""
positional = None
if "positional" in cfg:
    positional = Positional(cfg["positional"])
    positional_usage_string = positional.usage
    positional_usage.append(("  " + positional.long.upper(), positional.description))
    if positional.required:
        if positional.multiple:
            validation_statements.append(
                f'[[ -z "$1" ]] && {usage_statement(UsageType.STANDARD)}'
            )
        else:
            validation_statements.append(
                f"[[ -z ${positional.variable} ]] && {usage_statement(UsageType.STANDARD)}"
            )


# TODO use case for no options?
for o in cfg["options"]:
    opt = Option(o)
    variables.append(opt.variable)

    if opt.short:
        short_options.append(opt.getopt_short)

    case_statements.append(opt.case)
    long_options.append(opt.getopt_long)

    if opt.required:
        validation_statements.append(
            f"[[ -z ${opt.variable} ]] && {usage_statement(UsageType.STANDARD)}"
        )
        required_option_usage.append(opt.usage)
    else:
        optional_option_usage.append(opt.usage)

    if opt.default is not None:
        if type(opt.default) is bool:
            variables_with_defaults[opt.variable] = str(opt.default).lower()
        else:
            variables_with_defaults[opt.variable] = opt.default
    else:
        variables_with_no_default.append(opt.variable)

# max option length for usage text
mx = 0
for u in required_option_usage + optional_option_usage + positional_usage:
    mx = max(len(u[0]), mx)
mx += 3

# print it
newline = "\n"
print(
    f"""{usage_name}() {{
    echo "usage: {name} [OPTIONS]{positional_usage_string}

{newline.join([f'{u[0].ljust(mx)}{u[1]}' for u in sorted(positional_usage) + sorted(required_option_usage) + sorted(optional_option_usage)])}

{description}

Examples:
    {name}

See Also:
    reference" >&2"""
)
if getopt_type is GetoptType.SCRIPT:
    print("    exit 1")
print("}\n")


print(
    f'''{main_name}()  {{
    # Input Parsing
    local opts
    opts=$(getopt --options "{"".join(sorted(short_options))}" --longoptions "{",".join(sorted(long_options) + ["help"])}" -- "$@")
    [[ $? != "0" ]] && {usage_statement(UsageType.STANDARD)}
    eval set -- "$opts"'''
)
if len(variables_with_no_default) > 0:
    print(f'    local {" ".join(sorted(variables_with_no_default))}')
if len(variables_with_defaults) > 0:
    for v in sorted(variables_with_defaults.keys()):
        print(f'    local {v}="{variables_with_defaults[v]}"')
print(
    """    while :; do
        case "$1" in"""
)
for c in sorted(case_statements):
    print(f"            {c}")
print(
    f"""            --help) {usage_statement(UsageType.CASE)} ;;
            --) shift; break ;;
            *) {usage_statement(UsageType.CASE)} ;;
        esac
    done"""
)
if positional and not positional.multiple:
    print(f'    local {positional.variable}="$1"')

print(
    """
    # Input Validation"""
)
for v in sorted(validation_statements):
    print(f"    {v}")
print("\n    # Function")
if positional and positional.multiple:
    print(
        f"""    local {positional.variable}
    for {positional.variable} in "$@"; do
        implement_me
    done
}}"""
    )
else:
    print(
        """    implement_me
}"""
    )

if getopt_type is GetoptType.SCRIPT:
    print('main "$@"')
