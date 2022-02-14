/*关系与属性：
customers（user）：
	customerId     primary key     auto_increment
    balance       
    customerCredit
customersBlacklist： 用于记录信用为负数的顾客
	customerId
ecshop:  
	ecshopId      primary key     auto_increment;
    discount
    isOnSale
    ecshopCredit
    ecshopProfit    商家的盈利
ecshopBlacklist:    用于记录credit为负数的商家
	ecshopId
product：        产品库，存放所有产品
	productId
    ecshopId    此二者均为主码
    productprice
    productNumber     剩余产品数目
PaymentRecord：
	paymentId   主码
    customerId
    ecshopId
    productId
    customerState   记录商家此次交易中是否没有出现问题
    ecshopState     记录顾客在此次交易中是否没有出现问题
    payment         此次交易的金额
    
trigger 内容：
	1.当更新商店信息不为 isOnSale时，将商店折扣取消
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
*/

# 开发电商平台数据库 包括会员数据customer，交易浏览paymentRecord，商店信息ecshop，
# 商品信息product，发往城市city

set names utf8;
create database if not exists DatabaseProject ;
use `DatabaseProject`;

# 开始建立table
/*会员的信息*/
drop table if exists `customers`;
create table if not exists `customers`(
	`customerId` int(10) not null  auto_increment, /*指定显示int的宽度为11位，不足的用0补足*/
    `balance` int  not null   default 1000,
	`phone` int unique,
    `customerCredit` int not null   default 40,
    primary key(`customerId`)
)DEFAULT CHARSET=utf8 auto_increment = 32;

/*商店信息*/
drop table if exists `ecshop`;
create table if not exists `ecshop`(
	`ecshopId` int(10) primary key auto_increment,
    `keyCode` int,
	`isOnSale` int  default 1,
	`discount` float not null   default 0.8,
    `ecshopCredit` int not null   default 40,
    `ecshopProfit` int default 1000
)DEFAULT CHARSET=utf8;

/*用于更新商店的折扣：新店有8折*/
drop trigger if exists UpDate_Ecshop_Discount ;
delimiter $$
create trigger Update_Ecshop_Discount before update on `ecshop`
for each row
begin
	if new.`isOnSale` = 0
    then 
		set new.`discount` = 1;
	end if;
end $$
delimiter ;

/*商品信息*/
drop table if exists `product`;
create table if not exists `product`(
	`ecshopId` int(10) not null, 
	`productId` int(10) not null,
    `productName` varchar(10),
    `productPrice` numeric(5,2) unsigned not null   default 0,
	`productNumber` int unsigned not null   default 100,
    primary key(`ecshopId`,`productId`)
)DEFAULT CHARSET=utf8;

/*商店信用黑名单*/
drop table if exists `ecshopBlacklist`;
create table if not exists `ecshopBlacklist`(
    `ecshopId` int(10) primary key
)DEFAULT CHARSET=utf8;

/*顾客信用黑名单*/
drop table if exists `customersBlacklist`;
create table if not exists `customersBlacklist`(
	`customerId` int(10) primary key,
    `phone` int unique
)DEFAULT CHARSET=utf8;

/*付款记录*/
drop table if exists `paymentRecord`;
create table if not exists `paymentRecord`(
	`paymentId` int not null auto_increment,
    `customerId` int(10) not null, /*用于创建顾客视图*/
    `phone` int unique,
    `ecshopId` int(10) not null, 
    `productId` int(10) not null,
    `productNumber` int unsigned not  null   default 1,
    `customerState` bool not null default 0, /*与顾客的credit挂钩*/
    `ecshopState` bool not null default 0,/*与商店的credit挂钩*/
    `payment` int not null  default 0, /*付款金额*/
	primary key(`paymentId`)
)DEFAULT CHARSET=utf8; 

/*若插入数据前用户金额不足，抛出异常*/
drop trigger if exists Error_Detection_PaymentRecord ;
delimiter //
create trigger Error_Detection_PaymentRecord before insert on paymentRecord
for each row
begin
	declare tempBalance int;
    declare msg varchar(200);    
    set msg = "the customer does not have enough balance";
	set tempBalance = (select balance 
						from customers 
						where customers.customerId = new.customerId);
	if tempBalance < new.payment
    then
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = msg;
	end if;
end //
default charset = utf8;
delimiter ;

/*关于每个订单的credit更新*/
/*用于根据插入的交易记录更新商店与顾客的credit*/
drop trigger if exists Update_EcshopCredit_And_CustomerCredit ;
delimiter $$
create trigger Update_EcshopCredit_And_CustomerCredit after insert on paymentRecord
for each row 
begin
	if new.customerState = 1 and new.ecshopState = 1
    then 
		update `ecshop`
		set ecshop.ecshopCredit = ecshop.ecshopCredit + 5
        where ecshop.ecshopId = new.ecshopId;
        update `customers`
        set customers.customerCredit = customers.customerCredit + 5
        where customers.customerId = new.customerId;       
	elseif  (new.customerState = 1 and new.ecshopState = 0)
    then 
		update `ecshop`
		set ecshop.ecshopCredit = ecshop.ecshopCredit - 50
        where ecshop.ecshopId = new.ecshopId;
	elseif (new.customerState = 0 and new.ecshopState = 1)
    then
		update `customers`
		set customers.customerCredit = customers.customerCredit - 50
        where customers.customerId = new.customerId;
	else 
		update `customers`
		set customers.customerCredit = customers.customerCredit - 50
        where customers.customerId = new.customerId;
        update `ecshop`
		set ecshop.ecshopCredit = ecshop.ecshopCredit - 50
        where ecshop.ecshopId = new.ecshopId;
	end if;
end $$
delimiter ;

/*若发现ecshopCredit小于0，则加入ecshopBlacklist*/
drop trigger if exists Insert_EcshopBlacklist;
delimiter //
create trigger Insert_EcshopBlacklist after insert on paymentRecord
for each row
begin
	declare tempEcshopId,tempEcshopCredit int;
    set tempEcshopId = new.EcshopId;
	set tempEcshopCredit = 
		(select ecshop.ecshopCredit
		from `ecshop`
        where ecshop.ecshopId = new.ecshopId);
	if tempEcshopCredit < 0
    then
		insert
		into ecshopBlacklist values
		(tempEcshopId);  
    end if;
end //
delimiter ;

/*若发现customerCredit小于0，则加入customersBlacklist*/
drop trigger if exists Insert_CustomersBlacklist;
delimiter //
create trigger Insert_CustomersBlacklist after insert on paymentRecord
for each row
begin
	declare tempCustomerId,tempCustomerCredit,tempPhone int;
    set tempCustomerId = new.CustomerId;
    set tempPhone = new.phone;
	set tempCustomerCredit = 
		(select customers.CustomerCredit
		from `customers`
        where customers.customerId = new.customerId);
	if tempCustomerCredit < 0
    then
		insert
		into customersBlacklist values
		(tempCustomerId,tempPhone);  
    end if;
end //
delimiter ;

/*若发现ecshipCredit小于0，则删除*/
drop trigger if exists Delete_EcshopId;
delimiter //
create trigger Delete_EcshopId after insert on paymentRecord
for each row 
begin
	declare tempEcshopCredit int;
	set tempEcshopCredit = 
		(select ecshop.ecshopCredit
		from `ecshop`
        where ecshop.ecshopId = new.ecshopId);
	if tempEcshopCredit < 0
	then
		delete
        from ecshop
        where ecshop.ecshopId = new.ecshopId;
    end if;
end //
delimiter ;

/*若发现customerCredit小于0，则删除*/
drop trigger if exists Delete_CustomerId;
delimiter //
create trigger Delete_CustomerId after insert on paymentRecord
for each row 
begin
	declare tempCustomerCredit int;
	set tempCustomerCredit = 
		(select customers.customerCredit
		from `customers`
        where customers.customerId = new.customerId);
	if tempCustomerCredit < 0
	then
		delete
        from customers
        where customers.customerId = new.customerId;
    end if;
end //
delimiter ;

/*交易成功时，修改对应商店商品的数目*/
drop trigger if exists Insert_paymentRecord ;
delimiter // 
create trigger Insert_paymentRecord after insert on paymentRecord
for each row
begin
	if new.customerState = 1 and new.ecshopState = 1
    then
		update `product`
		set `product`.`productNumber` = `product`.`productNumber` - new.`productNumber`
		where `product`.`productId` = new.`productId` and `product`.`ecshopId` = new.`ecshopId`;
    end if;
end //
delimiter ;

/*当交易成功时，修改商店与用户的金额*/
drop trigger if exists Update_Balance_And_Profit;
delimiter //
create trigger Update_Balance_And_Profit after insert on paymentRecord
for each row
begin
	if new.customerState = 1 and new.ecshopState = 1
    then
		update customers
        set customers.balance = customers.balance - new.payment
        where new.customerId = customers.customerId;
        update ecshop
        set ecshop.ecshopProfit = ecshop.ecshopProfit + new.payment;
    end if;
end //
delimiter ;

/*建立procedure*/
/*用户购买一次商品时，调用该过程并传参*/
drop procedure if exists Perchasing_Product;
delimiter $$
create procedure  Perchasing_Product (In tempCustomerId int(10),
									  In tempPhone int,
									  In tempEcshopId int(10),
                                      In tempProductId int(10),
                                      In tempProductNumber int(10))
begin
    declare randomState1,randomState2,tempProductPrice,tempPayment int;
    declare tempDiscount float;
	declare error1,error2,error3 varchar(200);
    set error1 = "customer not exists or in blacklist";
    set error2 = "ecshop not exists or in blacklist";
    set error3 = 'product insufficient';
    
     /*设置随机数作为交易是否成功的依据，即customerState与ecshopState*/
	 #set randomState1 = round(rand()+0.2);
		#set randomState2 = round(rand()+0.2);
	
	 #set randomState1 = 0;
    #set randomState2 = 0;
    
	 set randomState1 = 1;
   set randomState2 = 1;

		#set randomState1 = 0;
    #set randomState2 = 1;

	#set randomState1 = 1;
    #set randomState2 = 0;

	/*计算此次购买的金额*/
    set tempDiscount = (select discount 
						from ecshop
                        where tempEcshopId = ecshop.ecshopId);
    set tempProductPrice = (select productPrice 
							from product
                            where tempEcshopId = product.ecshopId and tempProductId = product.productId);
    set tempPayment = tempProductNumber * tempProductPrice * tempDiscount;
    
	if tempCustomerId not in (select customerId from customers)
    then
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = error1;
	elseif tempCustomerId in (select customerId from customersBlacklist)
    then 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = error1;
	elseif tempPhone in (select phone from customersBlacklist)
    then 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = error1;
	end if;
    
	if tempEcshopId not in (select ecshopId from ecshop)
    then
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = error2;
	elseif tempEcshopId in (select ecshopId from ecshopBlacklist)
    then 
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = error2;
    end if; 
    
    if tempProductNumber > (select productNumber from product where productId = tempProductId and ecshopId = tempEcshopId)
    then
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = error3;
    end if;
    
    /*插入数据*/
    insert 
    into paymentRecord(customerId,
					   phone,
					   ecshopId,
                       productId,
                       productNumber,
                       customerState,
                       ecshopState,
                       payment) values
    (tempCustomerId,
	 tempPhone,
     tempEcshopId,
	 tempProductId,
     tempProductNumber,
     randomState1,
     randomState2,
     tempPayment);
end $$
delimiter ;

/*店铺进货*/
drop procedure if exists Ecshop_getMoreProduct;
delimiter //
create procedure Ecshop_getMoreProduct(In tempEcshopId int,In tempKeyCode int,In tempProductId int,In tempProductNumber int)
begin
	declare msg,error1,tempProductName,discription varchar(100);
    set error1 = 'Wrong keyCode';
    set msg = "ecshop not exists or in blacklist";
    set tempProductName = (select productName 
							from product 
                            where product.ecshopId = tempEcshopId and product.productId = tempProductId);
    
    if tempKeyCode != (select keyCode from ecshop where ecshopId = tempEcshopId)
    then 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = error1;
	end if;
	if tempEcshopId in (select ecshopId 
						from ecshopBlacklist 
                        where ecshopBlacklist.ecshopId = tempEcshopId)
	then
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = msg;
	end if;
    if tempEcshopId not in (select ecshopId 
								from ecshop 
								where ecshop.ecshopId = tempEcshopId)
	then 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = msg;
	end if;
    
    set discription = concat('Ecshop ',tempEcshopId," get ",tempProductNumber, ' ',tempProductName,' more');
    select discription;
	update product
	set product.productNumber = product.productNumber + tempProductNumber
	where product.ecshopId = tempEcshopId and product.productId = tempProductId;
end //
delimiter ;

/*商铺增加商品种类并进货*/
drop procedure if exists Ecshop_getNewProduct;
delimiter //
create procedure Ecshop_getNewProduct (In tempEcshopId int, 
									   In tempKeyCode int,
									   In tempProductName varchar(10),
                                       In tempProductPrice int, 
                                       In tempProductNumber int)
begin
	declare discription,msg,error1 varchar(100);
	declare tempProductId int; 
	set msg = "ecshop not exists or in blacklist";
	set error1 = 'Wrong keyCode';
    
    if tempKeyCode != (select keyCode from ecshop where ecshopId = tempEcshopId)
    then 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = error1;
	end if;
    
    /*生成店铺内唯一的商品Id*/
    repeat
		set tempProductId = floor(rand()*10000);
	until tempProductId not in( select productId 
								from product 
                                where product.ecshopId = tempEcshopId)
	end repeat;

	if tempEcshopId in (select ecshopId 
						from ecshopBlacklist 
                        where ecshopBlacklist.ecshopId = tempEcshopId)
	then
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = msg;
	end if;
    if tempEcshopId not in (select ecshopId 
								from ecshop 
								where ecshop.ecshopId = tempEcshopId)
	then 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = msg;
	end if;
    
    insert
    into product values
    (tempEcshopId,tempProductId,tempProductName,tempProductPrice,tempProductNumber);
    
    set discription = concat('Ecshop ', tempEcshopId ,"purchased ",tempProductId, ' ',tempProductName, '   number:',tempProductNumber,'   price:',tempProductPrice);
    select discription;
end //
delimiter ;

/*商铺更新自己的活动与折扣*/
drop procedure if exists Ecshop_UpdateDiscount;
delimiter //
create procedure Ecshop_UpdateDiscount(In tempEcshopId int,In tempKeyCode int,In tempDiscount float)
begin
	declare msg,error1 varchar(100);
	set msg = "ecshop not exists or in blacklist";
	set error1 = 'Wrong keyCode';
    
    if tempKeyCode != (select keyCode from ecshop where ecshopId = tempEcshopId)
    then 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = error1;
	end if;
    
    if tempEcshopId in (select ecshopId 
						from ecshopBlacklist 
                        where ecshopBlacklist.ecshopId = tempEcshopId)
	then
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = msg;
	end if;
    if tempEcshopId not in (select ecshopId 
								from ecshop 
								where ecshop.ecshopId = tempEcshopId)
	then 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = msg;
	end if;
    
	update ecshop
    set ecshop.discount = tempDiscount, isOnSale = 1
    where ecshop.ecshopId = tempEcshopId;
    
    set msg = concat("EcshopId:", tempEcshopId, ' update discount to:', tempDiscount);
    select msg;
end //
delimiter ;

/*商铺或顾客查看商品信息*/
drop procedure if exists Customer_Ecshop_Show_ProductInformation;
delimiter //
create procedure Customer_Ecshop_Show_ProductInformation(In tempEcshopId int)
begin
	declare msg varchar(100);
	set msg = "ecshop not exists or in blacklist";
    if tempEcshopId in (select ecshopId 
						from ecshopBlacklist 
                        where ecshopBlacklist.ecshopId = tempEcshopId)
	then
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = msg;
	end if;
    if tempEcshopId not in (select ecshopId 
								from ecshop 
								where ecshop.ecshopId = tempEcshopId)
	then 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = msg;
	end if;
    
	select * 
    from product
    where ecshopId = tempEcshopId;
end //
delimiter ;

/*商铺取消打折*/
drop procedure if exists Ecshop_NoOnSale;
delimiter //
create procedure Ecshop_NoOnSale(In tempEcshopId int,In tempKeyCode int)
begin
	declare msg,error1,msg2 varchar(100);
	set msg = "ecshop not exists or in blacklist";
	set error1 = 'Wrong keyCode';
    set msg2 = concat('Ecshop ',tempEcshopId,' not on sale now');
    
    if tempKeyCode != (select keyCode from ecshop where ecshopId = tempEcshopId)
    then 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = error1;
	end if;
    
    if tempEcshopId in (select ecshopId 
						from ecshopBlacklist 
                        where ecshopBlacklist.ecshopId = tempEcshopId)
	then
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = msg;
	end if;
    if tempEcshopId not in (select ecshopId 
								from ecshop 
								where ecshop.ecshopId = tempEcshopId)
	then 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = msg;
	end if;
    
    update ecshop
    set isOnSale = 0
    where ecshopId = tempEcshopId;
    select msg2;
end //
delimiter ;

/*商铺查看自己的店铺信息*/
drop procedure if exists Ecshop_Show_Information;
delimiter //
create procedure Ecshop_Show_Information(In tempEcshopId int,In tempKeyCode int)
begin
	declare msg,error1 varchar(100);
	set msg = "ecshop not exists or in blacklist";
	set error1 = 'Wrong keyCode';
    
    if tempKeyCode != (select keyCode from ecshop where ecshopId = tempEcshopId)
    then 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = error1;
	end if;
    
    if tempEcshopId in (select ecshopId 
						from ecshopBlacklist 
                        where ecshopBlacklist.ecshopId = tempEcshopId)
	then
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = msg;
	end if;
    if tempEcshopId not in (select ecshopId 
								from ecshop 
								where ecshop.ecshopId = tempEcshopId)
	then 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = msg;
	end if;
    
	select *
    from ecshop
    where ecshopId = tempEcshopId;
end //
delimiter ;

/*商铺查看自己的交易信息*/
drop procedure if exists Ecshop_Show_PaymentInformation;
delimiter //
create procedure Ecshop_Show_PaymentInformation(In tempEcshopId int)
begin
	declare msg varchar(100);
	set msg = "ecshop not exists or in blacklist";
    if tempEcshopId in (select ecshopId 
						from ecshopBlacklist 
                        where ecshopBlacklist.ecshopId = tempEcshopId)
	then
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = msg;
	end if;
    if tempEcshopId not in (select ecshopId 
								from ecshop 
								where ecshop.ecshopId = tempEcshopId)
	then 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = msg;
	end if;
    
	select * 
    from paymentRecord
    where ecshopId = tempEcshopId;
end //
delimiter ;

/*用户查看个人信息*/
drop procedure if exists Customer_Show_Information;
delimiter //
create procedure Customer_Show_Information (In tempCustomerId int)
begin
	declare msg varchar(100);
    set msg = 'customer not exists or in blacklist';
	if tempCustomerId not in (select customerId from customers)
    then
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = msg;
	end if;
	if tempCustomerId in (select customerId from customersBlacklist)
    then 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = msg;
	end if;
    
	select *
    from customers
    where customers.customerId = tempCustomerId;
end //
delimiter ;

/*用户查看商品*/
drop procedure if exists Customer_Show_Product;
delimiter //
create procedure Customer_Show_Product (In tempCustomerId int)
begin
	select ecshopId,productId,productName,productPrice
    from product
    where productNumber <> 0;
end //
delimiter ;

/*用户查看交易记录*/
drop procedure if exists Customer_Show_PaymentRecord;
delimiter //
create procedure Customer_Show_PaymentRecord(In tempCustomerId int)
begin
	select * 
    from paymentRecord
    where customerId = tempCustomerId;
end //
delimiter ;

/*创建用户*/
drop procedure if exists Customer_Creation;
delimiter //
create procedure Customer_Creation (In tempPhone int,In tempBalance int)
begin
	declare tempCustomerId int;
    declare error1,error2,error3,msg varchar(50);
    set error1 = 'customer created already';
    set error2 = 'You are in Blacklist';
    set error3 = 'balance denied';
    if tempPhone in (select phone from customers)
    then
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = error1;
	elseif tempPhone in (select phone from customersBlacklist)
    then 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = error2;
	end if;
    
    if tempBalance <= 0
    then 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = error3;
    end if;
    
    repeat
		set tempCustomerId = round(rand()*10000);
	until tempCustomerId not in (select customerId from customers)
    end repeat;
    
    insert
    into customers(customerId,phone,balance) values
    (tempCustomerId,tempPhone,tempBalance);
    set msg = concat('regedit succeed,your Id is ',tempCustomerId);
    select msg;
end //
delimiter ;

/*用户充值*/
drop procedure if exists Customer_Recharge;
delimiter //
create procedure Customer_Recharge (In tempCustomerId int,In recharge int)
begin 
	declare msg,error1,error2 varchar(50);
    set error1 = 'Recharge denied,check your number';
    set error2 = 'customer in blacklist';
    set msg = 'recharge succeed';
    
    if tempCustomerId in(select customerId from customersBlacklist)
    then
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = error2;
	elseif recharge <= 0
    then 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = error1;
	end if;
    
    update customers
    set balance = balance + recharge
    where customerId = tempCustomerId;
    select msg;
end //
delimiter ;








































/*
drop view if exists Ecshop_Product;
create view Ecshop_Product(productId,productName,productPrice,productNumber)
as
select productId,productName,productPrice,productNumber
from product
group by ecshopId;*/
/*
GRANT EXECUTE  ON  PROCEDURE `Perchasing_Product` TO 'XvZhiPeng'@'%';
GRANT EXECUTE  ON  PROCEDURE `Ecshop_UpdateDiscount` TO 'ChenYUYang'@'%';
GRANT EXECUTE  ON  PROCEDURE `Ecshop_getNewProduct` TO 'ChenYUYang'@'%';
GRANT EXECUTE  ON  PROCEDURE `Ecshop_getMoreProduct` TO 'ChenYUYang'@'%';
GRANT EXECUTE  ON  PROCEDURE `Show_Product_Information` TO 'ChenYUYang'@'%';
GRANT EXECUTE  ON  PROCEDURE `Show_Ecshop_Information` TO 'ChenYUYang'@'%';
GRANT EXECUTE  ON  PROCEDURE `Show_EcshopPayment_Information` TO 'ChenYUYang'@'%';*/
