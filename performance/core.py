from enum import Enum
from abc import ABC
from warnings import warn
from datetime import datetime

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
        
                
