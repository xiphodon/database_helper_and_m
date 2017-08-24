# -*- coding:utf-8 -*-

from neo4j.v1 import GraphDatabase, basic_auth


class Neo4jHandler:
    def __init__(self, host, user, password):
        """
        类初始化
        :param host: Neo4j 服务器
        :param user:
        :param password:
        """
        self.driver = GraphDatabase.driver(host, auth=basic_auth(user, password))
        self.session = self.driver.session()

    def query_id_card(self, id_card):
        """
        根据用户的身份证信息查询用户的申请记录
        :param id_card: 身份证号
        :return:
        """
        query_stat = """
            MATCH (u:USER{idCard:"%s"})-[rel:PHONE]->(p:PHONE)
            RETURN rel,p
        """ % id_card

        result = self.session.run(query_stat)
        return result

    def query_phone_num(self, phone_num):
        """
        根据手机号查询用户的申请记录信息
        :param phone_num:
        :return:
        """
        query_stat = """
            MATCH (u:USER)-[rel:PHONE]->(p:PHONE{phoneNum:"%s"})
                RETURN rel,u
        """ % phone_num

        result = self.session.run(query_stat)
        return result

    def query_emerge_num(self, phone_list):
        """
        根据手机号查询用户的申请记录信息
        :param phone_num:
        :return:
        """
        query_stat = """
            MATCH (c1:CONTACT)-[rel:EMERG]->(c2:CONTACT)
            WHERE c2.phoneNum in %s
            RETURN c1
        """ % phone_list

        result = self.session.run(query_stat)
        return result



    def  __del__(self):
        self.session.close()

if __name__ == '__main__':
    neo4j_handler = Neo4jHandler("bolt://47.93.193.219:7687", "neo4j1", "123$RFV04151")
    id_card = "130433199105132317"
    result = neo4j_handler.query_id_card(id_card)
    for record in result:
        print (record)