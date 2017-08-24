# -*- coding:utf-8 -*-

import pymysql


class MySQLHandler:
    """
    MySQL 访问工具类
    """

    def __init__(self, host, user, pwd, dbname):
        """
        初始化数据库连接
        :param host: 主机地址
        :param user: 数据库用户名
        :param pwd: 数据库密码
        :param db_name: 连接的数据库名
        """
        conn = pymysql.connect(host=host, user=user, passwd=pwd, db=dbname, charset='utf8')
        self.cursor = conn.cursor()

    def query_with_statement(self, statement):
        """
        执行SQL语句
        :param statement:
        :return:
        """
        self.cursor.execute(statement)
        return self.cursor.fetchall()

    def __del__(self):
        """
        释放连接
        :return:
        """
        self.cursor.close()

if __name__ == '__main__':
    mysql_handler = MySQLHandler("59.110.31.186","imass_bak1","_pBK01#19_1","imassbank1")
    sql_stat = """
      SELECT * FROM imassbank.imass_merchant;
    """
    result = mysql_handler.query_with_statement(sql_stat)
    for record in result:
        print (record)