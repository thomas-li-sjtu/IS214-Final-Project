use databaseProject;
set names utf8;
insert 
into ecshop(ecshopId,keyCode) values
(1,1),
(2,2),
(3,3),
(4,4),
(5,5),
(6,6),
(7,7);

insert
into customers(customerId,phone) values
(001,1359013),
(002,123123),
(003,456456),
(004,77777),
(005,2800),
(006,23333),
(007,8888),
(008,66666),
(009,8945);

insert 
into product values
(1,1,"baseball",20,50),
(1,2,"football",30,40),
(2,1,"apple",40,30),
(2,6,"HuaWei",12,100),
(2,3,"tennis",50,70),
(3,4,"medicine",40,100),
(4,1,"sweater",10,60),
(4,2,"wine",90,100),
(5,1,"shoes",60,50),
(5,2,"baseball",40,20),
(6,1,"Pork",50,10),
(6,2,"Beef",60,30),
(7,1,"HuaWei",30,30),
(7,2,"SanSung",10,10),
(7,3,"Apple",20,20);

insert 
into customersBlacklist values
(100,123789);

insert
into ecshopBlacklist values
(100),
(101),
(102);






#测试
######################################################################################################################
select * from customers;
select * from ecshop;
select * from product;
select * from customersBlacklist;
select * from ecshopBlacklist;
#####################################################################################################################
#table测试完毕，开始测试procedure
# 测试用户注册：用户输入自己手机号和初始金额
/*异常抛出*/
	/*1.黑名单用户重新注册*/
		#call Customer_Creation(123789,1000);
	/*2.用户设置的balance小于0*/
		#call Customer_Creation(1,-100);
/*注册成功*/
		#call Customer_Creation(1,100);
		#select * from customers where phone = 1;
        
# 测试用户充值：用户输入自己ID和充值金额     
/*异常抛出*/  
	/*1.黑名单充值*/
		#call Customer_Recharge (100,1000);
	/*2.充值金额错误*/
		#call Customer_Recharge (001,-3);
/*充值成功*/
		#call Customer_Recharge (001,99);
        #select * from customers where customerId = 001;

# 测试用户查看商品:用户输入自己的ID，查看所有商品
		#call Customer_Show_Product(2);
# 测试用户查看个人信息：用户输入自己ID
/*异常抛出*/
	/*1.用户不存在*/
		#call Customer_Show_Information(10000);
	/*2.用户在黑名单*/
		#call Customer_Show_Information(100);
/*成功*/
		#call Customer_Show_Information(007);

#商铺更新折扣信息：输入店铺Id，密码和折扣
/*异常抛出*/
	/*1.商铺不存在*/
		#call Ecshop_UpdateDiscount(100001,6,0.6);
	/*2.商铺在黑名单*/
		#call Ecshop_UpdateDiscount(101,7,0.6);
	/*3.密码错误*/
		#call Ecshop_UpdateDiscount(2,4,0.7);
/*成功*/
		#call Ecshop_UpdateDiscount(3,3,0.9);
        #select * from ecshop where ecshopId = 3;

#商铺取消打折活动，触发trigger
/*异常抛出*/
	/*1.商铺不存在*/
		#call Ecshop_NoOnSale(100000,6);
	/*2.商铺在黑名单*/
		#call Ecshop_NoOnSale(100,7);
	/*3.密码错误*/
		#call Ecshop_NoOnSale(7,6);
/*成功,检验trigger*/
		#call Ecshop_NoOnSale(2,2);
        #select * from ecshop where ecshopId = 2;
        
#商铺进货:此处不再测试异常,输入店铺id，密码，商品id和数目
		#call Ecshop_getMoreProduct(3,3,4,6);
		#select * from product where product.ecshopId = 3;
        
#商铺购置新商品 此处不测试异常 输入店铺id，密码，商品名，价格，数目
		#call Ecshop_getNewProduct(3,3,"drug",20,30);
		#select * from product where product.ecshopId = 3;

#商铺查看自己店铺信息:输入店铺Id和店铺密码
/*异常抛出*/
	/*1.商铺不存在*/
		#call Ecshop_Show_Information(100000,6);
	/*2.商铺在黑名单*/
		#call Ecshop_Show_Information(100,7);
	/*3.密码错误*/
		#call Ecshop_Show_Information(7,6);
/*成功*/
		#call Ecshop_Show_Information(7,7);
        
#商铺查看自己商品,此处不测试异常 输入商铺Id
		#call Customer_Ecshop_Show_ProductInformation(6);
###################################################################################################################
#procedure 测试完毕，开始测试trigger    购买：输入用户id，手机，店铺id，商品id，商品数目
#交易失败时，商品、店铺、用户均无金额损失
#测试用户余额不足异常，设置state均为1
/*手动设置与测试*/
		#update customers set balance = 2 where customerId = 005;
		#call Perchasing_Product(005,2800,1,1,2);
#测试用户交易失败，进入黑名单  设置用户state为0，商铺state为1
		#call Perchasing_Product(005,2800,1,1,2);
		#select * from customersBlacklist;
		#select * from paymentRecord;
		#select * from ecshop where ecshopId = 1;
#测试商铺交易失败，进入黑名单  设置用户state为1，商铺state为0
		#call Perchasing_Product(006,2800,1,1,2);
		#select * from ecshopBlacklist;
		#select * from paymentRecord;
        #select * from customers where customerId = 006;
#测试双方交易成功（双方均失败在此省略）
		call Perchasing_Product(006,2800,1,1,2);
		select * from ecshopBlacklist;
        select * from customersBlacklist;
		select * from paymentRecord;
        select * from customers where customerId = 006;
		select * from ecshop where ecshopId = 1;
        select * from product where ecshopId = 1 and productId = 1;






/*
call Ecshop_getMoreProduct(1,1,10);
call Ecshop_getNewProduct(2,"bed",200,3);
call Ecshop_UpdateDiscount(3,0.9);
select * from product;
select * from ecshop;*/
/*
insert
into paymentRecord(paymentId,customerId,ecshopId,productId,productNumber,ecshopState,customerState) values 
(1,009,1,1,2,1,1),
(2,008,2,1,3,1,1),
(3,007,2,3,4,1,1),
(4,006,2,1,5,1,1),
(10,005,5,2,1,1,1),
(5,005,3,4,6,1,1),
(6,003,3,4,7,0,0), 
(7,003,1,2,8,0,0),
(8,003,2,1,2,0,0);*/

/*
call Perchasing_Product(001,1,1,2);
call Perchasing_Product(002,1,2,2);
call Perchasing_Product(003,2,1,2);
call Perchasing_Product(004,3,4,2);
select * from ecshopBlacklist;
select * from customersblacklist;
call Perchasing_Product(005,1,1,2);
select * from ecshopBlacklist;
select * from customersblacklist;
call Perchasing_Product(001,2,3,2);
select * from ecshopBlacklist;
select * from customersblacklist;
call Perchasing_Product(001,1,1,2);
select * from ecshopBlacklist;
select * from customersblacklist;
call Perchasing_Product(001,1,2,2);
select * from ecshopBlacklist;
select * from customersblacklist;
call Perchasing_Product(001,1,2,2);
select * from ecshopBlacklist;
select * from customersblacklist;
call Perchasing_Product(001,1,2,2);
select * from ecshopBlacklist;
select * from customersblacklist;
call Perchasing_Product(001,1,2,2);
select * from ecshopBlacklist;
select * from customersblacklist;
call Perchasing_Product(001,1,2,2);
call Perchasing_Product(001,1,2,2);
call Perchasing_Product(001,1,2,2);
call Perchasing_Product(001,1,2,2);*/

/*
select * from paymentrecord;
select * from product;
select * from ecshop;
select * from ecshopBlacklist;
select * from customers;
select * from customersblacklist;*/
