
import urllib2
import urllib
import re
import time
import MySQLdb
import urllib2
import socket

#import socks
#import socket
#
#socks.set_default_proxy(socks.SOCKS5,"localhost",9150)
#socket.socket=socks.socksocket

#定义类爬取并处理
class powder:
 
    #初始化，传入基地址
    def __init__(self,baseUrl):
        self.baseURL = baseUrl
        
        #获取当前时间     
    def gettime(self):
         ISOTIMEFORMAT='%Y-%m-%d %X'
         current_time=time.strftime( ISOTIMEFORMAT, time.localtime() )
         return current_time

   #获取种子url页面上的源代码


    def getip(self):
        socket.setdefaulttimeout(3)
        f = open("C:\Users\lenovo\Documents\proxy.txt")
        lines = f.readlines()
        proxys = []
        for i in range(0,len(lines)):
            ip = lines[i].strip("\n").split("\t")
            proxy_host = "http://"+ip[0]
            proxy_temp = {"http":proxy_host}
            proxys.append(proxy_temp)
        url = "http://ip.chinaz.com/getip.aspx"
        for proxy in proxys:
            try:
                res = urllib.urlopen(url,proxies=proxy).read()
                if res!=[]:
                    print "可用",proxy
                    return proxy
                    break
                break
            except Exception,e:
                 print proxy
                 print e
                 continue
        return proxy
             
             
    def getPage(self,pagenum):
            try:
                url = self.baseURL+str(pagenum)
                user_agent = 'Mozilla/4.0 (compatible; MSIE 5.5; Windows NT)'
                #values = {'username' : '1935556799@qq.com',  'password' : '20160401' }
                #data = urllib.urlencode(values) 
#                socket.setdefaulttimeout(timeout)
#                sleep_download_time = 10 
                headers = { 'User-Agent' : user_agent,'Referer':url }
                request = urllib2.Request(url,headers = headers)
#                time.sleep(20) 
                proxy=self.getip()
                print proxy
                opener = urllib2.build_opener( urllib2.ProxyHandler(proxy) )
                urllib2.install_opener( opener )
                response = urllib2.urlopen(request)
                content=response.read()
                return content.decode('utf-8')
                response.close()
                time.sleep(2)
            except Exception as e:
                print e
                time.sleep(2)
                response=self.getPage(pagenum)
                return response
                
    def getPage_r(self,pagenum):
            try:
                url = self.baseURL+str(pagenum)
                user_agent = 'Mozilla/4.0 (compatible; MSIE 5.5; Windows NT)'
                #values = {'username' : '1935556799@qq.com',  'password' : '20160401' }
                #data = urllib.urlencode(values) 
#                socket.setdefaulttimeout(timeout)
#                sleep_download_time = 10 
                headers = { 'User-Agent' : user_agent,'Referer':url }
                request = urllib2.Request(url,headers = headers)
                response = urllib2.urlopen(request)
                content=response.read()
                return content.decode('utf-8')
                response.close()
                time.sleep(2)
            except Exception as e:
                print e
                time.sleep(2)
                response=self.getPage(pagenum)
                return response

   #获取页码
    def getPageNum(self,page):
        pattern=re.compile(r'&amp;first=(\d+)"',re.S)
        pgNum=list(set(re.findall(pattern,page)))
        if len(pgNum) ==0:
            pageNum=[0]
        else:    
            pagenum=[int(num) for num in pgNum]
            pagenum=max(pagenum)/20
            pageNum=[a*20 for a in range(0,pagenum+1)]  
        return pageNum
    
    #构建评论页的url,
    def getPage2(self,productid,num2=0):
        try:
            urls='http://www.gou.com/goods/comment.do?goodsId='+str(productid)+'&commentType=2&first='+str(num2)
            user_agent = 'Mozilla/4.0 (compatible; MSIE 5.5; Windows NT)'
            headers = { 'User-Agent' : user_agent,'Referer':urls }
#            socket.setdefaulttimeout(timeout)
#            sleep_download_time = 10 
#            time.sleep(sleep_download_time)      
            request = urllib2.Request(urls,headers = headers)
            response = urllib2.urlopen(request)
            content=response.read()            
            return content.decode('utf-8')
            response.close()
            time.sleep(2)
        except Exception as e:
            print e
            proxy=self.getip()
            print proxy
            opener = urllib2.build_opener( urllib2.ProxyHandler(proxy) )
            urllib2.install_opener( opener )
            response=self.getPage2(productid,num2)
            return response

    #对homepage上的数据进行切割
    def getsplit1(self,page):
        part=re.compile(r'<li onclick="HitsPosition(.*?)onclick="AlllistCollectGoods.*?">',re.S)
        part_split=re.findall(part,page)
        return part_split  
    
#    def getproductID(self,page):
#        productID=re.compile(r'<input type="button" goodid="(.*?)".*?/>',re.S)
#        product_IDs.extend(re.findall(productID,page))
#        return product_IDs

    def getpageintro(self,page):
        #匹配产品ID
        productID=re.compile(r'<input type="button" goodid="(.*?)".*?/>',re.S)
        #匹配产品名
        title=re.compile(r'<a href="/product.*?target="_blank" title="(.*?)" class="pica">',re.S)
        #匹配价格
        price=re.compile(r'<strong>.(\d+.\d+)</strong>',re.S)
        #匹配销量和评价数
        salenum=re.compile(r'<div style="display:none;">"(\d+)",',re.S)
        commentnum=re.compile(r'<span style="border-right: none;">.*?<span>.{2}\s(.*?)</span>',re.S)
        producturl=re.compile(r'<p><a href="(/product_.*?)" target="_blank"',re.S)
        product_url=re.findall(producturl,page)
        if product_url==[]:
            page_intro=[]
        else:
            productIDs=re.findall(productID,page)
            titles=re.findall(title,page)
            prices=list(set(re.findall(price,page)))
            salenums=re.findall(salenum,page)
            commentnums=re.findall(commentnum,page)
            page_intro=[productIDs,titles,prices,salenums,commentnums]            
        return page_intro

    def getsplit2(self,page):
        part=re.compile(r'<div class="comInfo">(.*?)<div class="botline"></div>',re.S)
        part_split=re.findall(part,page)
        return part_split      
        
        
    def getdetailed(self,page):
       #根据分割好的评论片段，获取购买产品ID，购买的产品名称，会员信息，账户名，时间，评论内容，回复内容，回复时间
       user=re.compile(r'</span>\s+(.*?)<span>&nbsp',re.S)
       commentcontent=re.compile(r'<p class="comMessage">(.*?)</p>',re.S)
       commenttime=re.compile(r'<span>&nbsp;&nbsp;(.*?)&nbsp;',re.S)
       reply=re.compile(r'<p class="reply">(.*?)<span>',re.S)
       replytime=re.compile(r'<p class="reply">.*?<span>(.*?)</span><br>',re.S)
       replycontent=re.compile(r'<p class="reply">.*?<span>.*?</span><br>(.*?)</p>')
       score=re.compile(r'style="width:(\d+)%;top:0px;">',re.S)
       user_name=re.findall(user,page)
       comment_content=re.findall(commentcontent,page)
       comment_time = re.findall(commenttime,page)
       reply_name=re.findall(reply,page)
       reply_content = re.findall(replycontent,page)
       reply_time = re.findall(replytime,page)
       scores=re.findall(score,page)
       scores=int(scores[0])/20       
       detailedpage=[user_name,comment_content,comment_time,reply_name,reply_content,reply_time,scores]
       return detailedpage
    
        
    def start(self):
         #连接数据库，关闭外键检查
        current_time=self.gettime() 
        conn=MySQLdb.connect(host='localhost',user='root',passwd='zhou',port=3306,db='mailegou2',charset='utf8')
        cur=conn.cursor()
        cur.execute('set foreign_key_checks=0')
        #由于RD_Site和RD_Target两个表需要单独写入，在此部分内容中主要写入rd_author和rd_page两个表
        #获取爬虫入口url的源码及页码
        indexPage = self.getPage(0)
        if indexPage==[]:
            print "该入口无法访问"
            pass
        else:
            pageNum = self.getPageNum(indexPage)
    #        print "该款奶粉共有"+str(len(pageNum))+"页"
            i=1        
            for num in pageNum:
                print "正在获取第"+str(i)+"页商品导航"
                pageshot = self.getPage_r(num)
                if pageshot == []:
                    print "该入口无法访问"
                    pass
                else:
        #            print pageshot
        #            product_IDs.extend(self.getproductID(pageshot))
                    part_split1=self.getsplit1(pageshot)
                    print "part_split1=",len(part_split1)
                    i+=1
                    for part in part_split1:
                        page_intro = self.getpageintro(part)
                        if page_intro==[]:
                            pass
                        else:
                            idss=page_intro[0]
                            ids=int(idss[0])
                            product_urls='http://www.gou.com/product_'+str(ids)+'.html'
                            cur.execute('insert into products(brand_id,product_site_id,product_name,price,sale_num,comment_num,product_url,create_dt) values(%s,%s,%s,%s,%s,%s,%s,%s)',(brandid,idss,page_intro[1],page_intro[2],page_intro[3],page_intro[4],product_urls,current_time))
                            key_productid=int(cur.lastrowid)                                                    
                            j=1    
                            print "正在获取产品ID为"+str(ids)+"的所有评论"
                            pageshot2 = self.getPage2(ids)
                            if pageshot2 == []:
                                print "该商品评论入口无法访问"
                                pass
                            else:
                                pageNum2 = self.getPageNum(pageshot2)
                                for num2 in pageNum2:
                                    pageshot3=self.getPage2(ids,num2)
                                    if pageshot3==[]:
                                        pass
                                    else:
                                        comment_urls='http://www.gou.com/goods/comment.do?goodsId='+str(ids)+'&commentType=2&first='+str(num2)
                                        part_split2 = self.getsplit2(pageshot3)
                                        for parts in part_split2:
                                            print "正在读取并存储第"+str(j)+"条评论"
                                            j+=1
                                            detailedpage= self.getdetailed(parts)
                                            cur.execute('insert into authors(site_id,author_nickname,create_dt) values(%s,%s,%s)',(siteid,detailedpage[0],current_time))                                    
                                            key_authorid=int(cur.lastrowid)
                                            if detailedpage[5] == []:
                                                cur.execute('insert into comments(belong_id,product_id,author_id,comment_content,comment_date,create_dt,score,comment_url) values(%s,%s,%s,%s,%s,%s,%s,%s)',(0,key_productid,key_authorid,detailedpage[1],detailedpage[2],current_time,detailedpage[6],comment_urls))        
                                            else:
                                                cur.execute('insert into comments(belong_id,product_id,author_id,comment_content,comment_date,create_dt,score,comment_url) values(%s,%s,%s,%s,%s,%s,%s,%s)',(0,key_productid,key_authorid,detailedpage[1],detailedpage[2],current_time,detailedpage[6],comment_urls))        
                                                key_replyid=int(cur.lastrowid)
                                                rp_name=detailedpage[3][0]
                                                rp_names="%s"%(rp_name)
                                                selectsql="select author_id from authors where author_nickname='%s'"%(rp_names)
                                                cur.execute(selectsql)                                              
                                                result = cur.fetchall()
                                                if len(result) == 0:
                                                    cur.execute('insert into authors(site_id,author_nickname,create_dt) values(%s,%s,%s)',(siteid,detailedpage[3],current_time))                                         
                                                    key_rp_au_id=int(cur.lastrowid)
                                                else:
                                                    key_rp_au_id=result[0][0]  
                                                cur.execute('insert into comments(belong_id,product_id,author_id,comment_content,comment_date,create_dt,comment_url) values(%s,%s,%s,%s,%s,%s,%s)',(key_replyid,key_productid,key_rp_au_id,detailedpage[4],detailedpage[5],current_time,comment_urls))        
                                
        conn.commit()
        cur.execute('set foreign_key_checks=1') 
        cur.close()
        conn.close()
        

urls = []

           
a=1
for urll in urls:
    print "目标为第"+str(a)+"个大类"
    baseURL=urll
    powder_crawel = powder(baseURL)
    brandid=int(a)
    siteid=5
    powder_crawel.start()
    print "已完成第"+str(a)+"类产品的存储"
    a+=1
