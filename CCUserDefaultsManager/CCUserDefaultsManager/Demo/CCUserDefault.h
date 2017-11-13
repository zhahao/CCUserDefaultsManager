//
//  CCUserDefault.h
//  CCUserDefaultsManager
//
//  Created by Zohar on 2017/11/9.
//  Copyright © 2017年 zohar. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CCUserDefault : NSObject

/// 使用单例
@property (class, readonly, strong) CCUserDefault *sharedManager;

/// c语言类型,支持整形和浮点型,包括NSInteger,CGFloat等
@property (nonatomic, assign) int intType;
@property (nonatomic, assign) float floatType;
@property (nonatomic, assign) double doubleType;
@property (nonatomic, assign) BOOL boolType;

/// oc对象类型,仅支持NSString, NSData, NSNumber, NSDate, NSArray, NSDictionary ,NSURL以及对应的可变类型
@property (nonatomic, strong) NSString *string;
@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) NSNumber *number;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, strong) NSArray *array;
@property (nonatomic, strong) NSDictionary *dictionary;
@property (nonatomic, strong) NSURL *url;

/// 忽略的成员变量
@property (nonatomic, strong) NSString *ignoreString;

@end

/// 可以根据不同种类,做不同的分类,以区分不同的业务逻辑,实现文件中使用@dynamic,避免编译器警告
@interface CCUserDefault(extension)

@property (nonatomic, strong) NSString *userName;

@end
