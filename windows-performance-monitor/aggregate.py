#!/usr/bin/env python
# coding: utf-8

import os
import re

import pandas as pd


class DataPicker:

    def __init__(self):
        self._df = pd.DataFrame
        self._out_df = pd.DataFrame
        self._server_name = ''
        self._col_names = list()

    def load(self, csv_file: str):
        df = pd.read_csv(csv_file, na_values=' ', encoding='ShiftJIS')
        m = re.match(r'\\\\SERVERNAME-[A-Z0-9\-]+', str(df.columns[1]))
        self._server_name = m.group(0)
        self._df = df

    def set_target(self, target_file: str):
        with open(target_file, 'r', encoding='utf-8') as fpr:
            for col_name in fpr:
                self._col_names.append(col_name.rstrip())

    def pickup(self, **kwargs):
        new_series_list = list()
        if kwargs.get('wide', False):
            agg_cols = ['mean', 'max', 'min', 'median', 'std']
        else:
            agg_cols = ['mean', 'max']
        for col_name in self._col_names:
            try:
                new_series = self._df[self._server_name+col_name].agg(agg_cols)
            except KeyError:
                new_series = pd.Series()
            new_series.name = col_name
            new_series_list.append(new_series)
        self._out_df = pd.DataFrame(new_series_list, columns=agg_cols)

    def write(self, filename):
        self._out_df.to_csv(filename)

    def show(self):
        print(self._out_df)


class AggregatorBase:
    MODES = ('high', 'normal')
    SERVERS = list()
    QUERIES = list()
    NUMBERS = list()

    BASEDIR = ''
    SRC_PATH = BASEDIR + '/sources/'
    PICK_PATH = BASEDIR + '/picked/'
    AGGR_PATH = BASEDIR + '/aggregated/'

    COL_FILENAME_BASE = BASEDIR + '/columns-{}.txt'

    def __init__(self):
        self.run_all = False
        self.col_file = ''
        self.wide_pickup = False

    @staticmethod
    def get_filename(mode, server, query, number):
        return '{}-{}-{}-{}.csv'.format(mode, server, query, number)

    def aggregate(self, mode, query):
        cat_df = pd.DataFrame()
        print('aggregating {}-{}... '.format(mode, query), end='')
        for server in self.SERVERS:
            for number in self.NUMBERS:
                filename = self.get_filename(mode, server, query, number)
                filename = self.PICK_PATH + filename
                # dst_filename = self.dst_filename_base.format(mode, server, query, number)
                try:
                    df = pd.read_csv(filename, index_col=0)
                    for in_name, in_series in df.iteritems():
                        col_name = '{}-{} {}'.format(server, number, in_name)
                        cat_df[col_name] = in_series
                except FileNotFoundError:
                    print('failed! [{}-{} not found]'.format(server, number))
                    return
        os.makedirs(self.AGGR_PATH, exist_ok=True)
        aggr_filename = self.AGGR_PATH + '{}-{}.csv'.format(mode, query)
        cat_df.to_csv(aggr_filename)
        print('succeeded.')

    def proc_each(self, mode, server, query, number):
        filename = self.get_filename(mode, server, query, number)
        col_filename = self.COL_FILENAME_BASE.format(server)

        src_file = self.SRC_PATH + filename
        print('picking data {}... '.format(src_file), end='')
        if not os.path.exists(src_file):
            print('failed! [file not found]')
        else:
            dp = DataPicker()
            dp.load(src_file)
            if not self.col_file:
                dp.set_target(col_filename)
            else:
                dp.set_target('{}/{}'.format(self.BASEDIR, self.col_file))
            dp.pickup(wide=self.wide_pickup)
            os.makedirs(self.PICK_PATH, exist_ok=True)
            dp.write(self.PICK_PATH + filename)
            print('succeeded.')

    def run(self, **kwargs):
        self.run_all = kwargs.get('all', False)
        self.col_file = kwargs.get('col_file', '')
        self.wide_pickup = kwargs.get('wide_pickup', False)
        concat_only = kwargs.get('concat_only', False)
        for query in self.QUERIES:
            for mode in self.MODES:
                if not concat_only:
                    for server in self.SERVERS:
                        for number in self.NUMBERS:
                            self.proc_each(mode, server, query, number)
                self.aggregate(mode, query)


class BatchAggregator(AggregatorBase):
    SERVERS = list('type1', 'type2', 'type3')
    QUERIES = list('query4', 'query1', 'query2', 'query3')
    NUMBERS = list(1, 2, 3)

    BASEDIR = './batch'
    SRC_PATH = BASEDIR + '/sources/'
    PICK_PATH = BASEDIR + '/picked/'
    AGGR_PATH = BASEDIR + '/aggregated/'

    COL_FILENAME_BASE = BASEDIR + '/columns-{}.txt'

    def __init__(self):
        super().__init__()


class TransactionAggregator(AggregatorBase):
    SERVERS = list('type3',)
    QUERIES = list('quert1', 'query2', 'query3')
    NUMBERS = list(1, 2, 3)

    BASEDIR = './transaction'
    SRC_PATH = BASEDIR + '/sources/'
    PICK_PATH = BASEDIR + '/picked/'
    AGGR_PATH = BASEDIR + '/aggregated/'

    COL_FILENAME_BASE = BASEDIR + '/columns-{}.txt'

    def __init__(self):
        super().__init__()


col_file = 'target_columns.txt'

# aggr = TransactionAggregator()
aggr = BatchAggregator()
aggr.run(col_file=col_file, wide_pickup=False, concat_only=False)
