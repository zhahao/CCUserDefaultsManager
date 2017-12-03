//
//  CCUserDefaultsManager.h
//  CCUserDefaultsManager
//
//  Created by Zohar on 2017/11/9.
//  Copyright © 2017年 zohar. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 这是一个用来集中式管理NSUserDefaults存储的框架,使用`[[CCUserDefaultsManager sharedManager] addClass:XXClass]`方法时,
 那么`XXClass`的所有成员变量的`get`和`set`都会映射成NSUserDefaults对应的存取方法.
 支持的存储类型:
    1.c语言类型,仅支持整形、浮点型、布尔型,包括NSInteger,CGFloat等
    2.oc对象类型,仅支持NSString, NSData, NSNumber, NSDate, NSArray, NSDictionary ,NSURL等不可变版本
 */
@interface CCUserDefaultsManager : NSObject

/// 单例
@property (class, readonly, strong) CCUserDefaultsManager *sharedManager;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

/// 添加需要和NSUserDefaults映射的class,多次添加同一个class,最终只会被添加一次.
- (void)addClass:(Class)cls;

/// 添加一个映射class和它的所有属性前缀
- (void)addClass:(Class)cls prefix:(NSString *)prefix;

/// 更新已经和NSUserDefaults映射的class,当你使用runtime修改了过类的成员变量时,需要更新.
- (void)updateClass:(Class)cls;

/// 删除已经和NSUserDefaults映射的class,并恢复原来class的property实现.
- (void)removeClass:(Class)cls;

@end

@protocol CCUserDefaultsManager<NSObject>

/// 如果有不需要被关联到NSUserDefaults的成员属性,请加入该黑名单,
/// 如果该类已经添加了统一的前缀,那么返回的数组里面的名称就不再需要添加前缀
+ (NSArray<NSString *> *)cc_blackList;

@end


