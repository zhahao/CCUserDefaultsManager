//
//  CCUserDefaultsManager.m
//  CCUserDefaultsManager
//
//  Created by Zohar on 2017/11/9.
//  Copyright © 2017年 zohar. All rights reserved.
//

#import "CCUserDefaultsManager.h"
#import <objc/runtime.h>

static NSString *const kCCUserDefaultsManagerObjectUnSupportError = @"CCUserDefaultsManagerObjectUnSupportError";
static NSString *const kCCUserDefaultsManagerCTypeUnSupportError = @"CCUserDefaultsManagerCTypeUnSupportError";

#define CC_LOCK     dispatch_semaphore_wait([CCUserDefaultsManager sharedManager].lock, DISPATCH_TIME_FOREVER);
#define CC_UNLOCK   dispatch_semaphore_signal([CCUserDefaultsManager sharedManager].lock);

typedef NS_ENUM(NSUInteger, CCEncodingType) {
    /// C types
    CCEncodingCTypeMask             = 0xFF,
    CCEncodingTypeUnSupport         = 0,  ///< unSupport type
    CCEncodingTypeInt               = 1,  ///< int
    CCEncodingTypeFloat             = 2,  ///< float
    CCEncodingTypeDouble            = 3,  ///< double
    CCEncodingTypeBOOL              = 4,  ///< bool
    CCEncodingTypeObject            = 5,  ///< Object

    /// OC types
    CCEncodingOCTypeMask            = 0xFF00,
    CCEncodingOCTypeUnSupport       = 1 << 8,   ///< unSupport obeject type
    CCEncodingOCTypeNSString        = 1 << 9,   ///< NSString
    CCEncodingOCTypeNSData          = 1 << 10,  ///< NSString
    CCEncodingOCTypeNSNumber        = 1 << 11,  ///< NSData
    CCEncodingOCTypeNSDate          = 1 << 12,  ///< NSDate
    CCEncodingOCTypeNSArray         = 1 << 13,  ///< NSArray
    CCEncodingOCTypeNSDictionary    = 1 << 14,  ///< NSDictionary
    CCEncodingOCTypeNSURL           = 1 << 15   ///< NSURL
};

/// class's property's informations
@interface CCClassPropertyInfo : NSObject
@property (nonatomic, strong, readonly) NSString *name; ///< property's name
@property (nonatomic, assign, readonly) CCEncodingType type;    ///< property's type
@property (nonatomic, strong, readonly) NSString *typeEncoding; ///< property's encoding value
@property (nonatomic, strong, readonly) NSString *getterMethodSignature;   ///< property's getterMethodSignature value
@property (nonatomic, strong, readonly) NSString *setterMethodSignature;   ///< property's setterMethodSignature value
@property (nonatomic, strong, readonly) Class cls;  ///< may be nil
@property (nonatomic, strong, readonly) NSArray<NSString *> *protocols; ///< may nil
@property (nonatomic, assign, readonly) SEL  getter; ///< getter
@property (nonatomic, assign, readonly) SEL  setter; ///< setter
@property (nonatomic, assign) IMP setterImp;   ///< class's setter IMP value
@property (nonatomic, assign) IMP getterImp;   ///< class's getter IMP value
- (instancetype)initWithProperty:(objc_property_t)property;
@end

/// class's property's informations
@interface CCClassInfo : NSObject
- (instancetype)initWithClass:(Class)class;
@property (nonatomic,strong, readonly) NSDictionary<NSString *,CCClassPropertyInfo *> *propertyInfos; ///< all properties info for class
@end

/// UserDefaultsManager
@interface CCUserDefaultsManager()
@property (nonatomic, strong) NSMutableDictionary<NSString *,CCClassInfo *> *classInfos; ///< swizzled class's infos
@property (nonatomic, strong) NSMutableSet<NSString *> *swizzledClasses; ///< all classes only swizzled once
@property (nonatomic, strong) dispatch_semaphore_t lock; ///< lock
@end

@implementation CCUserDefaultsManager

#pragma mark - Private Helper
/// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
static CCEncodingType ModelGetTypeEncoding(const char *type){
    if (!type || strlen(type) == 0) return CCEncodingTypeUnSupport;
    switch (*type) {
        case 'c': case 'i': case 's': case 'l': case 'q': case 'C': case 'I': case 'S': case 'L':
        case 'Q': return CCEncodingTypeInt;
        case 'v': case '*': case '#': case ':': case '[': case '{': case '(': case 'b': case '^':
        case '?': return CCEncodingTypeUnSupport;
        case 'f': return CCEncodingTypeFloat;
        case 'd': return CCEncodingTypeDouble;
        case 'B': return CCEncodingTypeBOOL;
        case '@': {
            if (type ++ && *type == '?') {
                return CCEncodingTypeUnSupport;
            }else{
                return CCEncodingTypeObject;
            }
        };
        default: return CCEncodingTypeUnSupport;
    }
}

/// class for type encoding
static CCEncodingType ModelGetOCTypeEncoding(Class class){
    if (!class) return CCEncodingOCTypeUnSupport;
    if ([class isSubclassOfClass:NSString.class]) return CCEncodingOCTypeNSString;
    if ([class isSubclassOfClass:NSData.class]) return CCEncodingOCTypeNSData;
    if ([class isSubclassOfClass:NSNumber.class]) return CCEncodingOCTypeNSNumber;
    if ([class isSubclassOfClass:NSDate.class]) return CCEncodingOCTypeNSDate;
    if ([class isSubclassOfClass:NSArray.class]) return CCEncodingOCTypeNSArray;
    if ([class isSubclassOfClass:NSDictionary.class]) return CCEncodingOCTypeNSDictionary;
    if ([class isSubclassOfClass:NSURL.class]) return CCEncodingOCTypeNSURL;
    return CCEncodingOCTypeUnSupport;
}

NS_INLINE NSUserDefaults *userDefaults(){
    return [NSUserDefaults standardUserDefaults];
}

NS_INLINE NSString *unSupportOCTypeError(id object){
    return [NSString stringWithFormat:@"<%@:%@ is not support save to userDefaults>",[object class],object];
}

NS_INLINE void setValueForUserDefaults(void (^block)(NSUserDefaults *userDefaults)){
    if (block) {
        block(userDefaults());
        [userDefaults() synchronize];
    }
}

static CCClassPropertyInfo *getClassPropertyInfo(id self,SEL _cmd,bool isSetter)
{
    Class cls = object_getClass(self);
    CCClassInfo *classInfos = [CCUserDefaultsManager sharedManager].classInfos[NSStringFromClass(cls)];
    NSDictionary *propertyInfos = classInfos.propertyInfos;

    __block NSString *selName = nil;
    [propertyInfos enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull name,
                                                       CCClassPropertyInfo  *_Nonnull info,
                                                       BOOL * _Nonnull stop) {
        if ([NSStringFromSelector(_cmd) isEqualToString:NSStringFromSelector(info.setter)] ||
            [NSStringFromSelector(_cmd) isEqualToString:NSStringFromSelector(info.getter)]) {
            selName = info.name;
            *stop = YES;
        }
    }];
    return selName ? propertyInfos[selName] : nil;
}

#pragma mark - Swizzled setter And getter IMP
void swizzledSetterIMPForDouble(id self,SEL _cmd,double value)
{
    CC_LOCK;
    setValueForUserDefaults(^(NSUserDefaults *userDefaults) {
        CCClassPropertyInfo *propertyInfo = getClassPropertyInfo(self,_cmd,true);
        [userDefaults setDouble:value forKey:propertyInfo.name];
    });
    CC_UNLOCK;
}

void swizzledSetterIMPForFloat(id self,SEL _cmd,float value)
{
    CC_LOCK;
    setValueForUserDefaults(^(NSUserDefaults *userDefaults) {
        CCClassPropertyInfo *propertyInfo = getClassPropertyInfo(self,_cmd,true);
        [userDefaults setFloat:value forKey:propertyInfo.name];
    });
    CC_UNLOCK;
}

double swizzledGetterIMPForDouble(id self,SEL _cmd)
{
    CCClassPropertyInfo *propertyInfo = getClassPropertyInfo(self,_cmd,true);
    return [userDefaults() doubleForKey:propertyInfo.name];
}

float swizzledGetterIMPForFloat(id self,SEL _cmd)
{
    CCClassPropertyInfo *propertyInfo = getClassPropertyInfo(self,_cmd,true);
    return [userDefaults() floatForKey:propertyInfo.name];
}

void swizzledSetterIMPForObject(id self,SEL _cmd,void *value)
{
    CC_LOCK;
    CCClassPropertyInfo *propertyInfo = getClassPropertyInfo(self,_cmd,true);
    CCEncodingType cType = propertyInfo.type & CCEncodingCTypeMask;

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *key = propertyInfo.name;

    if (cType == CCEncodingTypeObject){
        CCEncodingType ocType = propertyInfo.type & CCEncodingOCTypeMask;
        if (ocType & CCEncodingOCTypeUnSupport) {
            // 不支持的存储类型
            @throw [NSException exceptionWithName:kCCUserDefaultsManagerObjectUnSupportError
                                           reason:unSupportOCTypeError((__bridge id)value)
                                         userInfo:nil];
        }else if (ocType & CCEncodingOCTypeNSURL) {
            [userDefaults setURL:(__bridge NSURL*)value forKey:key];
        }else{
            @try {
                // 存储的NSDictionary,NSDictionary等里面包含了不支持的数据类型会发生错误.
                [userDefaults setObject:(__bridge id)value forKey:key];
            } @catch (NSException *exception) {
                NSLog(@"%@",exception);
            }
        }
    }else if (cType == CCEncodingTypeInt){
        [userDefaults setInteger:(NSInteger)value forKey:key];
    }else if (cType == CCEncodingTypeBOOL){
        [userDefaults setBool:(BOOL)value forKey:key];
    }
    [userDefaults synchronize];
    CC_UNLOCK;
}

void *swizzledGetterIMPForObject(id self,SEL _cmd)
{
    CCClassPropertyInfo *propertyInfo = getClassPropertyInfo(self,_cmd,false);
    CCEncodingType cType = propertyInfo.type & CCEncodingCTypeMask;

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *key = propertyInfo.name;

    void *rtv = NULL;
    if (cType == CCEncodingTypeObject){
        CCEncodingType ocType = propertyInfo.type & CCEncodingOCTypeMask;
        if (ocType & CCEncodingOCTypeNSString) {
            rtv = (__bridge void *)[userDefaults stringForKey:key];
        }else if (ocType & CCEncodingOCTypeNSData) {
            rtv = (__bridge void *)[userDefaults dataForKey:key];
        }else if (ocType & CCEncodingOCTypeNSNumber) {
            rtv = (__bridge void *)[userDefaults objectForKey:key];
        }else if (ocType & CCEncodingOCTypeNSDate) {
            rtv = (__bridge void *)[userDefaults objectForKey:key];
        }else if (ocType & CCEncodingOCTypeNSArray){
            rtv = (__bridge void *)[userDefaults arrayForKey:key];
        }else if (ocType & CCEncodingOCTypeNSDictionary){
            rtv = (__bridge void *)[userDefaults dictionaryForKey:key];
        }else if (ocType & CCEncodingOCTypeNSURL){
            rtv = (__bridge void *)[userDefaults URLForKey:key];
        }else{
            @throw [NSException exceptionWithName:kCCUserDefaultsManagerObjectUnSupportError
                                           reason:unSupportOCTypeError(self)
                                         userInfo:nil];
        }
    }else if (cType == CCEncodingTypeInt){
        rtv = (void *)[userDefaults integerForKey:key];
    }else if (cType == CCEncodingTypeBOOL){
        rtv = (void *)(long)[userDefaults boolForKey:key];
    }else {
        @throw [NSException exceptionWithName:kCCUserDefaultsManagerCTypeUnSupportError reason:@"do not support this C type" userInfo:nil];
    }
    return rtv;
}


#pragma mark - Public API
+ (instancetype)sharedManager
{
    static CCUserDefaultsManager *_manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manager = [[self alloc] init];
    });
    return _manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _swizzledClasses = [NSMutableSet set];
        _classInfos = [NSMutableDictionary dictionary];
        _lock = dispatch_semaphore_create(1);
    }

    return self;
}

- (void)addClass:(Class)cls
{
    CC_LOCK;
    NSString *className = NSStringFromClass(cls);
    NSMutableSet *swizzledClasses = [CCUserDefaultsManager sharedManager].swizzledClasses;
    if (![swizzledClasses containsObject:className]) {
        [self swizzleClassWithName:className];
        [swizzledClasses addObject:className];
    }
    CC_UNLOCK;
}

- (void)updateClass:(Class)cls
{
    [self removeClass:cls];
    [self addClass:cls];
}

- (void)removeClass:(Class)cls
{
    CC_LOCK;
    NSString *className = NSStringFromClass(cls);
    NSMutableSet *swizzledClasses = [CCUserDefaultsManager sharedManager].swizzledClasses;
    if ([swizzledClasses containsObject:className]) {
        CCClassInfo *classInfo = _classInfos[className];
        [classInfo.propertyInfos enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, CCClassPropertyInfo * _Nonnull info, BOOL * _Nonnull stop) {
            // 恢复替换之前的getter和setter的IMP
            class_replaceMethod(cls, info.setter, info.setterImp, [info.setterMethodSignature cStringUsingEncoding:NSUTF8StringEncoding]);
            class_replaceMethod(cls, info.getter, info.getterImp, [info.getterMethodSignature cStringUsingEncoding:NSUTF8StringEncoding]);
        }];
        [swizzledClasses removeObject:className];
        [_classInfos removeObjectForKey:className];
    }
    CC_UNLOCK;
}


- (void)swizzleClassWithName:(NSString *)className
{
    Class class = NSClassFromString(className);
    CCClassInfo *classInfo = [[CCClassInfo alloc] initWithClass:class];

    [classInfo.propertyInfos enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull name, CCClassPropertyInfo * _Nonnull info, BOOL * _Nonnull stop) {
        if ([class respondsToSelector:@selector(cc_blackList)]) {
            if ([[class cc_blackList] containsObject:name]) return ;
        }

        CCEncodingType type = info.type & CCEncodingCTypeMask;
        // 对不支持的存储类型直接返回
        if (type == CCEncodingTypeUnSupport) return ;
        if (type == CCEncodingTypeObject && (info.type & CCEncodingOCTypeMask & CCEncodingOCTypeUnSupport)) return ;

        IMP setterIMP = NULL;
        IMP getterIMP = NULL;
        if (type == CCEncodingTypeFloat) {
            setterIMP = (IMP)swizzledSetterIMPForFloat;
            getterIMP = (IMP)swizzledGetterIMPForFloat;
        }else if (type == CCEncodingTypeDouble){
            setterIMP = (IMP)swizzledSetterIMPForDouble;
            getterIMP = (IMP)swizzledGetterIMPForDouble;
        }else{
            setterIMP = (IMP)swizzledSetterIMPForObject;
            getterIMP = (IMP)swizzledGetterIMPForObject;
        }
        
        // 使用方法替换完成调剂
        class_replaceMethod(class, info.setter, setterIMP, [info.setterMethodSignature cStringUsingEncoding:NSUTF8StringEncoding]);
        class_replaceMethod(class, info.getter, getterIMP, [info.getterMethodSignature cStringUsingEncoding:NSUTF8StringEncoding]);
    }];

    _classInfos[className] = classInfo;
}

@end


@implementation CCClassPropertyInfo

- (instancetype)initWithProperty:(objc_property_t)property
{
    self = [super init];
    if (!self) return nil;
    if (!property) return nil;

    _type = CCEncodingTypeUnSupport;
    _name = [NSString stringWithUTF8String:property_getName(property)];
    _getter = _name ? NSSelectorFromString(_name) : nil;
    _setter = _name ? NSSelectorFromString([NSString stringWithFormat:@"set%@%@:",
                                            [[_name substringWithRange:NSMakeRange(0, 1)] uppercaseString],
                                            [_name substringWithRange:NSMakeRange(1, _name.length - 1)]]) : nil;
    unsigned int outCount;
    objc_property_attribute_t *attrPtr = property_copyAttributeList(property, &outCount);

    for (unsigned int i = 0; i < outCount; i ++) {
        objc_property_attribute_t attr = attrPtr[i];

        const char *name = attr.name;
        switch (name[0]) {
            case 'T':{
                const char *value = attr.value;
                _typeEncoding = [NSString stringWithUTF8String:value];
                _type |= ModelGetTypeEncoding(value);
                NSString *types = _typeEncoding;
                if ((_type & CCEncodingTypeObject) && _typeEncoding.length) {
                    types = @"@";
                    NSScanner *scanner = [NSScanner scannerWithString:_typeEncoding];
                    if(![scanner scanString:@"@\"" intoString:NULL]) continue;
                    NSString *clsName;
                    [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"<\""] intoString:&clsName];
                    if (clsName) {
                        _cls = NSClassFromString(clsName);
                        _type |= ModelGetOCTypeEncoding(_cls);
                    }

                    NSMutableArray *protocols = nil;
                    while ([scanner scanString:@"<" intoString:NULL]) {
                        NSString *protocolName = nil;
                        if ([scanner scanUpToString:@">" intoString:&protocolName]) {
                            if (protocolName.length) {
                                if (!protocols) protocols = [NSMutableArray array];
                                [protocols addObject:protocolName];
                            }
                        }
                        [scanner scanString:@">" intoString:NULL];
                    }
                }
                _setterMethodSignature = [NSString stringWithFormat:@"@:%@",types];
                _getterMethodSignature = [NSString stringWithFormat:@"%@@:",types];
            }break;
            default: break;
        }
    }
    if (attrPtr) {
        free(attrPtr);
        attrPtr = NULL;
    }
    return self;
}


@end

@implementation CCClassInfo

- (instancetype)initWithClass:(Class)class
{
    self = [super init];
    if (!self) return nil;
    if (!class) return nil;

    NSMutableDictionary *propertyInfos = [NSMutableDictionary dictionary];
    unsigned int outCount;
    objc_property_t *list = class_copyPropertyList(class, &outCount);
    for (unsigned int i = 0; i < outCount; i ++) {
        objc_property_t t = list[i];
        CCClassPropertyInfo *info = [[CCClassPropertyInfo alloc] initWithProperty:t];
        // 记录下原来的setter和getter的IMP指针
        info.getterImp = class_getMethodImplementation(class, info.getter);
        info.setterImp = class_getMethodImplementation(class, info.setter);
        if (info.name){
            propertyInfos[info.name] = info;
        }
    }
    if (list) {
        free(list);
        list = NULL;
    }
    _propertyInfos = propertyInfos.count ? [propertyInfos copy] : nil;

    return self;
}

@end
