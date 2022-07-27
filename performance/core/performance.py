import argparse
import datetime
from enum import Enum
import errno
import json
import os
from warnings import warn

class TimeBucket(Enum):
    NONE = 'none'
    DAY = 'day'
    HOUR = 'hour'
    MINUTE = 'minute'

class Request():
    def __init__(self, line, separator, http_method_index, url_index, response_code_index, duration_index, date_index=None, time_index=None, datetime_index=None, datetime_format=None):
        self._fields = line.split(separator)

        # direct fields
        self.url = self._fields[url_index]
        self.http_method = self._fields[http_method_index]
        self.http_response_code = self._fields[response_code_index]
        self.duration = self._fields[duration_index]

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

        if not (date_index and time_index) and not datetime_index:
            raise Exception('must specify either (date_index and time_index) or datetime_index')
        if datetime_index:
            datetime_str = self._fields[datetime_index]
        else:
            datetime_str = f'{self._fields[date_index]} {self._fields[time_index]}'
        if datetime_format:
            self.request_time = datetime.strptime(datetime_str, datetime_format)
        else:
            self.request_time = datetime.fromisoformat(datetime_str)

_HTTP_RESPONSE_FIELDS = ['2XX', '4XX', '5XX', 'No Response', 'Other']
_PERCENTILE_FIELDS = ['50p', '75p', '90p', '99p']

def date_filter(request, start_date=None, end_date=None):
    d = request.request_time.date()
    if start_date is not None and d < start_date:
        return False
    if end_date is not None and d > end_date:
        return False
    return True

def url_filter(request, pattern, reverse_match=False):
    if request.path.contains(pattern):
        if reverse_match:
            return False
        else:
            return True
    else:
        if reverse_match:
            return True
        else:
            return False

def performance_report(logs, request_parser, component_parser, request_filter, time_bucket: TimeBucket = TimeBucket.NONE, include_query=False):
    no_bucket, by_day, by_hour, by_minute = _time_bucket_bools(time_bucket)

    skipped = []
    components = set()

    dicts = []
    times = {}
    dicts.append(times)
    response_code_details = {}
    dicts.append(response_code_details)
    inbound_http = {}
    dicts.append(inbound_http)
    
    # process the logs
    for filename in logs:
        with open(filename, 'r') as file:
            component = component_parser(filename)
            if component not in components:
                components.add(component)
                for d in dicts:
                    d[component] = {}
            for line in file.readlines():
                req = request_parser(line)
                if not request_filter(req):
                    continue
                _process_times(req, component, times)
                if req.duration is None or req.duration == 0:
                    _process_performance(req, component, inbound_http, time_bucket, include_query, omit_duration=True)
                else:
                    _process_performance(req, component, inbound_http, time_bucket, include_query)

    # generate the report
    root_path = 'out'
    _mkdir(root_path)
    index = open(f'{root_path}/index.html', 'w')
    cfiles = {}
    _init(index, times)
    index.write('<table>\n<tr>\n<th>Component</th>\n</tr>\n')

    for component in sorted(components):
        index.write(f'<tr><td><a href="{component}/index.html">{component}</a></td></tr>\n')

    for label, data in zip(['inbound'], [inbound_http]):
        for component in data:
            if component not in cfiles:
                _mkdir(f'{root_path}/{component}')
                cfiles[component] = open(f'{root_path}/{component}/index.html', 'w')
                _init(cfiles[component], component)
            if len(data[component].keys()) == 0:
                continue
            output = cfiles[component]
            if no_bucket:
                table_headers = ['url', 'method', 'requests'] + _HTTP_RESPONSE_FIELDS + _PERCENTILE_FIELDS
                mergeable_columns = 1
            if by_day:
                table_headers = ['url', 'date', 'method', 'requests'] + _HTTP_RESPONSE_FIELDS + _PERCENTILE_FIELDS
                mergeable_columns = 2
            if by_hour:
                table_headers = ['url', 'date', 'hour', 'method', 'requests'] + _HTTP_RESPONSE_FIELDS + _PERCENTILE_FIELDS
                mergeable_columns = 3
            if by_minute:
                table_headers = ['url', 'date', 'minute', 'method', 'requests'] + _HTTP_RESPONSE_FIELDS + _PERCENTILE_FIELDS
                mergeable_columns = 3
            data_handler = http_performance_data_handler
            _write_table(output, data[component], label, table_headers, mergeable_columns, data_handler)

    if len(skipped) > 0:
        with open('skipped.json', 'w') as skipped_file:
            for j in skipped:
                skipped_file.write(json.dumps(j))
        warn(f'skipped {len(skipped)} records - see skipped.json for details')

def _time_bucket_bools(time_bucket: TimeBucket):
    # no_bucket, by_day, by_hour, by_minute = _time_bucket_bools(time_bucket)
    no_bucket = time_bucket == TimeBucket.NONE
    by_day = time_bucket == TimeBucket.DAY
    by_hour = time_bucket == TimeBucket.HOUR
    by_minute = time_bucket == TimeBucket.MINUTE
    return no_bucket, by_day, by_hour, by_minute

#
# Log processing
#

def _get_root(data, req, prepend_keys, time_bucket):
    no_bucket, by_day, by_hour, by_minute = _time_bucket_bools(time_bucket)
    root = data
    for key in prepend_keys:
        if key not in root:
            root[key] = {}
        root = root[key]
    if by_day or by_hour or by_minute:
        req_date = str(req.request_time.date())
        if req_date not in root:
            root[req_date] = {}
        root = root[req_date]
    if by_hour:
        req_hour = req.request_time.hour
        k = f'{req_hour}:00'
        if k not in root:
            root[k] = {}
        root = root[k]
    if by_minute:
        req_hour = req.request_time.hour
        req_min = req.request_time.minute
        k = f'{req_hour}:0{req_min}' if req_min < 10 else f'{req_hour}:{req_min}'
        if k not in root:
            root[k] = {}
        root = root[k]
    return root


def _process_times(req, component, times):
    if 'start' not in times[component] or times[component]['start'] > req.request_time:
        times[component]['start'] = req.request_time
    if 'end' not in times[component] or times[component]['end'] < req.request_time:
        times[component]['end'] = req.request_time

def _process_performance(req, component, inbound_http, time_bucket, include_query, omit_duration=False):
    # bucket the response code
    if req.http_response_code != '0':
        if req.http_response_code[0] in ['2','4','5']:
            req.http_response_code = req.http_response_code[0] + 'XX'
        else:
            req.http_response_code = 'Other'
    
    # standardize the url
    url_key = req.path
    if include_query:
        url_key = req.url
    
    # determine correct place to write data
    # assume inbound for now
    data = inbound_http[component]

    # write it
    root = _get_root(data, req, [url_key], time_bucket)
    if req.http_method not in root:
        root[req.http_method] = {}
    root = root[req.http_method]
    if 'count' not in root:
        root['count'] = 1
        if omit_duration:
            root['duration'] = []
        else:
            root['duration'] = [req.duration]
        root['response'] = {}
        root['response'][req.http_response_code] = 1
    else:
        root['count'] += 1
        if not omit_duration:
            root['duration'].append(req.duration)
        if req.http_response_code not in root['response']:
            root['response'][req.http_response_code] = 1
        else:
            root['response'][req.http_response_code] += 1


#
# Report Generation
#

def _init(html, times, header=None):
    html.write('<html>\n<link rel="stylesheet" href="https://unpkg.com/mvp.css">\n')
    html.write('<style>\ntable {\noverflow-x: visible;\n}\n')
    html.write('th {\nposition: -webkit-sticky;\nposition: sticky;\ntop: 0;\nbackground: white;\nz-index: 2;\n}\n')
    html.write('.merged-table {\nborder-collapse: collapse;\n}\n')
    html.write('.merged-cell {\nborder-top: 1px solid;\nborder-bottom: 1px solid;\n}\n</style>\n')
    if header is not None:
        html.write(f'<h1>{header}</h1>\n')
        if 'start' in times[header]:
            html.write(f'''<p>
log start time: {times[header]["start"].strftime("%Y-%m-%d %H:%M:%S (UTC)")}<br>
log end time: {times[header]["end"].strftime("%Y-%m-%d %H:%M:%S (UTC)")}
</p>''')

def _mkdir(path):
    try:
        os.makedirs(path)
    except OSError as e:
        if e.errno != errno.EEXIST:
            raise

def _table_header(html_file, column_labels):
    html_file.write('<table class="merged-table">\n<tr>\n')
    for column_label in column_labels:
        html_file.write(f'<th>{column_label}</th>\n')
    html_file.write('</tr>\n')

def _table_row(html_file, data, rowspan=None):
    if rowspan is None:
        rowspan = []
    html_file.write('<tr>\n')
    for index, d in enumerate(data):
        rowspan_html = ''
        if len(rowspan) > 0:
            rowspan_html = f' class="merged-cell" rowspan="{rowspan.pop(0)}"'
        if isinstance(d, str) and len(d) > 80:
            full = d
            while len(d) > 80:
                if "/" in d:
                    _, d = d.split('/',1)
                    preslash = '/'
                else:
                    d = d[-79:]
                    preslash = ''
            html_file.write(f'<td{rowspan_html} title="full">...{preslash}{str(d).replace("<", "&lt;").replace(">", "&gt;")}</td>\n')
        else:
            html_file.write(f'<td{rowspan_html}>{str(d).replace("<", "&lt;").replace(">", "&gt;")}</td>\n')
    html_file.write('</tr>\n')

def _parse(root):
    http_responses = []
    for field in _HTTP_RESPONSE_FIELDS:
        f = field
        if field == 'No Response':
            f = '0'
        if f in root['response']:
            http_responses.append(f'{round((root["response"][f] / root["count"]) * 100)}% ({root["response"][f]})')
        else:
            http_responses.append('-')
    durations = root['duration']
    durations.sort()

    p50 = '-'
    p75 = '-'
    p90 = '-'
    p99 = '-'
    if len(durations) > 0:
        p50 = f'{durations[round((len(durations) - 1) / 2)]}ms'
    if len(durations) > 2:
        p75 = f'{durations[round(3 * (len(durations) - 1) / 4)]}ms'
    if len(durations) > 4:
        p90 = f'{durations[round(9 * (len(durations) - 1) / 10)]}ms'
    if len(durations) > 10:
        p99 = f'{durations[round(99 * (len(durations) - 1) / 100)]}ms'
    return http_responses, [p50, p75, p90, p99]

def _get_merged_size(data, target_depth, depth=1):
    if depth == target_depth:
        return len(data)
    size = 0
    for key in data:
        size += _get_merged_size(data[key], target_depth, depth + 1)
    return size

def _write_table(html_file, data, header, table_headers, mergeable_columns, data_handler):
    html_file.write(f'<h2>{header}</h2>\n')
    _table_header(html_file, table_headers)
    merged_index = 0
    current = data
    merge_count = []
    iterators = []
    values = []
    data_row = []
    while True:
        # get the mergeable parts
        while len(iterators) < mergeable_columns + 1:
            iterators.append(iter(sorted(current)))
            values.append(next(iterators[-1]))
            if len(iterators) < mergeable_columns:
                merge_count.append(_get_merged_size(current[values[-1]], target_depth=mergeable_columns, depth=len(merge_count) + 1))
            else:
                merge_count.append(1)
            data_row.append(values[-1])
            current = current[values[-1]]
        
        # fill in the rest of the data row
        data_row += data_handler(current)

        # print it
        _table_row(html_file, data_row, rowspan=[x for x in merge_count[merged_index:-1] if x > 1])

        # clean up
        merge_count = [x - 1 for x in merge_count]
        while merge_count[-1] == 0 and (len(merge_count) > 1 and merge_count[-2] == 0):
            merge_count.pop()
            iterators.pop()
            values.pop()
        
        # setup for next data row
        data_row = []
        current = data
        merge_count.pop()
        merged_index = len(merge_count)
        values.pop()
        try:
            values.append(next(iterators[-1]))
        except StopIteration:
            # we're done
            break
        for value in values:
            current = current[value]
        if len(iterators) <= mergeable_columns:
            merge_count.append(_get_merged_size(current, target_depth=mergeable_columns, depth=len(merge_count) + 1))
        else:
            merge_count.append(1)
        data_row.append(values[-1])
    
    html_file.write('</table></br>\n')

def http_performance_data_handler(root):
    http_responses, percentiles = _parse(root)
    return [root['count']] + http_responses + percentiles

def other_data_handler(root):
    return [root['count']]