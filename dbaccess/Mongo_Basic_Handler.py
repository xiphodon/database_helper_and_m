# -*- coding:utf-8 -*-
from pymongo import MongoClient


class MongoHandler:
    """
    MongoDB 处理类
    """
    def __init__(self, host, user, password, database):
        """
        类初始化
        :param host:
        :param user:
        :param password:
        """
        params = "mongodb://" + user + ":" + password + "@" + host + "/" + database
        print(params)
        self.client = MongoClient(params)
        self.database = self.client[database]

    def query_by_bson(self,table_name,bson):
        """
        查询信息
        :param table_name:
        :param bson:
        :return:
        """
        mongo_res = self.database[table_name].find(bson)
        return mongo_res

    def __del__(self):
        """
        析构函数
        :return:
        """
        self.client.close()

if __name__ == "__main__":
    mongo_handler = MongoHandler(host = "59.110.31.186",user="imassbank-bak1",password="I1q#az45$91",database="imassbank11251")
    bson = {}
    bson['uid'] = "26576"
    table = "I_MO_B_B_RISK"
    mongo_res = mongo_handler.query_by_bson(table,bson)
    for record in mongo_res:
        print(record)