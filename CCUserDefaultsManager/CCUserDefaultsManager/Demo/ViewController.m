//
//  ViewController.m
//  CCUserDefaultsManager
//
//  Created by Zohar on 2017/11/9.
//  Copyright © 2017年 zohar. All rights reserved.
//

#import "ViewController.h"
#import "CCUserDefault.h"
#import "CCUserDefaultsManager.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self storeToUserDefaults];
    [self printUserDefaults];
    [self fetchFromUserDefaults];
}

// 删除关联,并恢复class原来的成员变量存取方法
- (void)removeClass
{
    [[CCUserDefaultsManager sharedManager] removeClass:[CCUserDefault class]];
    CCUserDefault *defaults = [CCUserDefault sharedManager];
    defaults.intType = 100;
    NSLog(@"defaults-intType=%d",defaults.intType);
}

// 存入NSUserDefault
- (void)storeToUserDefaults {
    CCUserDefault *defaults = [CCUserDefault sharedManager];

    // 每一次的set方法都是在向NSUserDefaults中存值
    defaults.intType = 1;
    defaults.floatType = 2.222;
    defaults.doubleType = 3.3333333;
    defaults.boolType = YES;

    defaults.string = @"string";
    defaults.data = [@"data" dataUsingEncoding:NSUTF8StringEncoding];
    defaults.number = @10;
    defaults.date = [NSDate date];
    defaults.array = @[@1,@2,@3];
    defaults.dictionary = @{ @"key1" : @"value1" , @"key2" : @"value2"};
    defaults.url = [NSURL URLWithString:@"http://www.apple.com"];
    
    defaults.ignoreString = @"ignoreString";
    
    defaults.userName = @"apple";
}

// 从NSUserDefaults取出来
- (void)fetchFromUserDefaults {
    // 每一次的get方法都是在向NSUserDefaults中取值
    CCUserDefault *defaults = [CCUserDefault sharedManager];
    NSLog(@"%@",defaults);
}

// 打印NSUserDefaults
- (void)printUserDefaults {
    [[NSUserDefaults standardUserDefaults].dictionaryRepresentation enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSLog(@"key:%@,value:%@",key,obj);
    }];
}


@end
