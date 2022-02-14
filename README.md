## IS214

数据库原理课程项目——电商平台模拟



关系与属性：

customers（user）：

​	customerId   primary key   auto_increment

​	balance    

​	customerCredit

customersBlacklist： 用于记录信用为负数的顾客

​	customerId

ecshop:  

​	ecshopId    primary key   auto_increment;

​	discount

​	isOnSale

​	ecshopCredit

​	ecshopProfit   商家的盈利

ecshopBlacklist:   用于记录credit为负数的商家

​	ecshopId

product：     产品库，存放所有产品

​	productId

​	ecshopId   此二者均为主码

​	productprice

​	productNumber   剩余产品数目

PaymentRecord：

​	paymentId  主码

​	customerId

​	ecshopId

​	productId

​	customerState  记录商家此次交易中是否没有出现问题

​	ecshopState   记录顾客在此次交易中是否没有出现问题

​	payment     此次交易的金额

  

trigger 内容：

  1.当更新商店信息不为 isOnSale 时，将商店折扣取消

  2.当用户金额不足时，抛出异常

  3.当用户金额足够，检测交易双方是否出现问题，更新双方信用

  4.当用户或商店信用不足（小于0）时，将用户Id和商店Id拉入黑名单，并从用户表和商店表中删除用户、商店

  5.当交易成功时，更新商品库的商品数目

  6.当交易成功时，更新商店profit与用户余额

procedure 内容：

  1.用户购买商品时，检测用户Id是否存在或商铺Id是否存在（包括检查二者是否在黑名单中），若不存在，抛出异常终止交易

   这里关于用户的state和商铺的state是随机数

  2.商铺更新产品的数目（进货）

  3.商铺更新产品种类,并进货

  4.商铺更新自己的活动与折扣

  5.创建用户

待增加的功能：

procedure：

  5.建立店铺

  6.加入用户   