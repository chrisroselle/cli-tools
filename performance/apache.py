import argparse
import datetime
import shlex
from core import performance
from warnings import warn

def component_from_filename(filename):
    return 'example'

def request_filter(request):
    return True

class ApacheRequest():
    def __init__(self, line):
        self._fields = shlex.split(line)

        # direct fields
        self.url = self._fields[5].split(" ")[1]
        self.http_method = self._fields[5].split(" ")[0]
        self.http_response_code = self._fields[6]
        self.duration = self._fields[11]

        # processed from direct fields
        self.path = self.url.split('?')[0]
        self.query_params = {}
        if '?' in self.url:
            self.query = self.url.split('?')[1]
            for pair in self.query.split('&'):
                l = pair.split('=')
                if len(l) != 2:
                    warn(f'skipped query parameter in unexpected format, length !=2 after split on "=" - param->"{pair}"')
                    continue
                self.query_params[l[0]] = l[1]

        self.request_time = datetime.datetime.strptime(f'{self._fields[3]} {self._fields[4]}', '[%d/%b/%Y:%H:%M:%S %z]').astimezone(datetime.timezone.utc)
        
parser = argparse.ArgumentParser(
    description = 'Calculate statistics from access logs and output simple HTML report with the results'
)
parser.add_argument('--time-bucket', '-t', help='Which time period to bucket the results', choices=list(performance.TimeBucket), type=performance.TimeBucket)
parser.add_argument('--include-query', '-q', help='Include query string when sorting URLs', action='store_true')
parser.add_argument('log', nargs='+', help='The log files to calculate statistics from')
parser.set_defaults(include_query=False,time_bucket=performance.TimeBucket.NONE)
args = parser.parse_args()     

performance.performance_report(args.log, ApacheRequest, component_from_filename, request_filter, args.time_bucket, args.include_query)
