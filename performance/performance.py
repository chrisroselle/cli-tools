import argparse
import core
import errno
import json
import os
import pprint
import sys
from warnings import warn

parser = argparse.ArgumentParser(
    description = 'Calculate statistics from access logs and output simple HTML report with the results'
)
parser.add_argument('--time-bucket', '-t', help='Which time period to bucket the results', choices=[x.value for x in core.TimeBucket], type=core.TimeBucket)
parser.add_argument('--include-query', '-q', help='Include query string when sorting URLs', action='store_true')
parser.add_argument('--separator', '-s', help='Field separator for log lines')
parser.add_argument('log', nargs='+', help='The log files to calculate statistics from')
parser.set_defaults(include_query=False,time_bucket=core.TimeBucket.NONE,separator=' ')
args = parser.parse_args()

no_bucket = args.time_bucket == core.TimeBucket.NONE
by_day = args.time_bucket == core.TimeBucket.DAY
by_hour = args.time_bucket == core.TimeBucket.HOUR
by_minute = args.time_bucket == core.TimeBucket.MINUTE

def component_from_filename(filename):
    pass

skipped = []

dicts = []
times = {}
dicts.append(times)
response_code_details = {}
dicts.append(response_code_details)
inbound_http = {}
dicts.append(inbound_http)

def get_root(data, prepend_keys):
    root = data
    for key in prepend_keys:
        if key not in root:
            root[key] = {}
        root = root[key]
    if by_day or by_hour or by_minute:
        req_date = str(req.start_time.date())
        if req_date not in root:
            root[req_date] = {}
        root = root[req_date]
    if by_hour or by_minute:
        req_hour = req.start_time.hour
        k = f'{req_hour}:00'
        if k not in root:
            root[k] = {}
        root = root[k]
    if by_minute:
        req_min = req.start_time.minute
        k = f'{req_hour}:0{req_min}' if req_min < 10 else f'{req_hour}:{req_min}'
        if k not in root:
            root[k] = {}
        root = root[k]
    return root


def process_times(req, component):
    if 'start' not in times[component] or times[component]['start'] > req.start_time:
        times[component]['start'] = req.start_time
    if 'end' not in times[component] or times[component]['end'] < req.start_time:
        times[component]['end'] = req.start_time

def process_performance(req, component, omit_duration=False):
    # bucket the response code
    if req.http_response_code != '0':
        if req.http_response_code[0] in ['2','4','5']:
            req.http_response_code = req.http_response_code[0] + 'XX'
        else:
            req.http_response_code = 'Other'
    
    # standardize the url
    url_key = req.path
    if args.include_query:
        url_key = req.url
    
    # determine correct place to write data
    # assume inbound for now
    data = inbound_http[component]

    # write it
    root = get_root(data, [url_key])
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

for filename in args.log:
    with open(filename, 'r') as file:
        component = component_from_filename(filename)
        for line in file.readlines():
            req = core.Request(line, args.separator, args.http_method_index, args.url_index, args.response_code_index, args.duration_index, args.date_index, args.time_index, args.datetime_index, args.datetime_format)
            process_times(req, component)
            if req.duration is None or req.duration == 0:
                process_performance(req, component, omit_duration=True)
            else:
                process_performance(req, component)


###############################
###############################

#
# Generate the report
#

def init(html, header=None):
    html.write('<html>\n<link rel="stylesheet" href="https://unpkg.com/mvp.css">\n')
    html.write('<style>\ntable {\noverflow-x: visible;\n}\n')
    html.write('th {\nposition: -webkit-sticky;\nposition: sticky;\ntop: 0\nbackground: white;\nz-index: 2;\n}\n')
    html.write('.merged-table {\nborder-collapse: collapse;\n}\n')
    html.write('.merged-cell {\nborder-top: 1px solid;\nborder-bottom: 1px solid;\n}\n</style>\n')
    if header is not None:
        html.write(f'<h1>{header}</h1>\n')
        if 'start' in times[header]:
            html.write(f'''<p>
log start time: {times[header]["start"].strftime("%Y-%m-%d %H:%M:%S (UTC)")}<br>
log end time: {times[header]["end"].strftime("%Y-%m-%d %H:%M:%S (UTC)")}
</p>''')

def mkdir(path):
    try:
        os.makedirs(path)
    except OSError as e:
        if e.errno != errno.EEXIST:
            raise

def table_header(html_file, column_labels):
    html_file.write('<table class="merged-table">\n<tr>\n')
    for column_label in column_labels:
        html_file.write(f'<th>{column_label}</th>\n')
    html_file.write('</tr>\n')

def table_row(html_file, data, rowspan=[]):
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

def parse(root):
    http_responses = []
    for field in http_response_fields:
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

def get_merged_size(data, target_depth, depth=1):
    if depth == target_depth:
        return len(data)
    size = 0
    for key in data:
        size += get_merged_size(data[key], target_depth, depth + 1)
    return size

def write_table(html_file, data, header, table_headers, mergeable_columns, data_handler):
    html_file.write(f'<h2>{header}</h2>\n')
    table_header(html_file, table_headers)
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
                merge_count.append(get_merged_size(current[values[-1]], target_depth=mergeable_columns, depth=len(merge_count) + 1))
            else:
                merge_count.append(1)
            data_row.append(values[-1])
            current = current[values[-1]]
        
        # fill in the rest of the data row
        data_row += data_handler(current)

        # print it
        table_row(html_file, data_row, rowspan=[x for x in merge_count[merged_index:-1] if x > 1])

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
            merge_count.append(get_merged_size(current, target_depth=mergeable_columns, depth=len(merge_count) + 1))
        else:
            merge_count.append(1)
        data_row.append(values[-1])
    
    html_file.write('</table></br>\n')

    def http_performance_data_handler(root):
        http_responses, percentiles = parse(root)
        return [root['count']] + http_responses + percentiles

    def other_data_handler(root):
        return [root['count']]

    root_path = 'out'
    mkdir(root_path)
    index = open(root_path, '/index.html', 'w')
    cfiles = {}
    init(index)
    index.write('<table>\n<tr>\n<th>Component</th>\n</tr>\n')

    for component in sorted(components):
        index.write(f'<tr><td><a href="{component}/index.html">{component}</a></td></tr>\n')

    http_response_fields = ['2XX', '4XX', '5XX', 'No Response', 'Other']
    percentile_fields = ['50p', '75p', '90p', '99p']
    for label, data in zip(['inbound'], [inbound_http]):
        for component in data:
            if component not in cfiles:
                mkdir(f'{root_path}/{component}')
                cfiles[component] = open(f'{root_path}/{component}/index.html', 'w')
                init(cfiles[component], component)
            if len(data[component].keys()) == 0:
                continue
            output = cfiles[component]
            if no_bucket:
                table_headers = ['url', 'method', 'requests'] + http_response_fields + percentile_fields
                mergeable_columns = 1
            if by_day:
                table_headers = ['url', 'date', 'method', 'requests'] + http_response_fields + percentile_fields
                mergeable_columns = 2
            if by_hour:
                table_headers = ['url', 'date', 'hour', 'method', 'requests'] + http_response_fields + percentile_fields
                mergeable_columns = 3
            if by_minute:
                table_headers = ['url', 'date', 'minute', 'method', 'requests'] + http_response_fields + percentile_fields
                mergeable_columns = 3
            data_handler = http_performance_data_handler
            write_table(output, data[component], label, table_headers, mergeable_columns, data_handler)

    if len(skipped) > 0:
        with open('skipped.json', 'w') as skipped_file:
            for j in skipped:
                skipped_file.write(json.dumps(j))
        warn(f'skipped {len(skipped)} records - see skipped.json for details')