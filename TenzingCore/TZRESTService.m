//
//  TZRESTService.m
//  TenzingCore
//
//  Created by Endika Gutiérrez Salas on 11/2/12.
//  Copyright (c) 2012 Tenzing. All rights reserved.
//

#import "TZRESTService.h"
#import "NSObject+Additions.h"
#import "NSArray+Additions.h"

@implementation TZRESTService

- (id)init
{
    self = [super init];
    if (self) {
        self.operationQueue = [[NSOperationQueue alloc] init];
    }
    return self;
}

+ (NSString *)generatePathFromSchema:(NSString *)schema params:(NSMutableDictionary *)params
{
    static NSRegularExpression *regex = nil;
    if (!regex) {
        NSError *error;
        regex = [NSRegularExpression regularExpressionWithPattern:@":[a-zA-Z0-9_]+"
                                                          options:0
                                                            error:&error];
    }
    NSMutableString *resultSchema = [schema mutableCopy];
    
    [regex enumerateMatchesInString:schema options:0 range:NSMakeRange(0, schema.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        NSString *key = [schema substringWithRange:NSMakeRange(result.range.location + 1, result.range.length - 1)];
        [resultSchema replaceCharactersInRange:result.range withString:params[key]];
        //[params removeObjectForKey:key];
    }];
    
    return resultSchema;
}

+ (void)routePath:(NSString *)path method:(NSString *)method class:(Class)class as:(SEL)sel
{
    [self defineMethod:sel do:^id(TZRESTService *_self, ...) {
        va_list ap;
        va_start(ap, _self);
        id params = va_arg(ap, id);
        void(^callback)(id, NSURLResponse *, NSError *) = va_arg(ap, id);
        va_end(ap);
        
        NSString *resultPath = [self generatePathFromSchema:path params:params];
        NSURL *url = [NSURL URLWithString:resultPath relativeToURL:_self.baseURL];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = method;
        [request setValue:@"application/json" forHTTPHeaderField:@"accept"];
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:((TZRESTService *) _self).operationQueue
                               completionHandler:^(NSURLResponse *resp, NSData *data, NSError *error) {
                                   if (error) {
                                       // Conection Error
                                       callback(data, resp, error);
                                       return;
                                   }
                                   NSError *serializationError;
                                   id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&serializationError];
                                   
                                   if (serializationError) {
                                       // Serialization error
                                       callback(data, resp, serializationError);
                                       return;
                                   }
                                   if (!class) {
                                       // Object can't be mapped
                                       callback(object, resp, nil);
                                       return;
                                   }
                                   
                                   if ([object isKindOfClass:NSArray.class]) {
                                       callback([((NSArray *) object) transform:^id(id obj) {
                                           return [obj isKindOfClass:NSDictionary.class]
                                           ? [[class alloc] initWithValuesInDictionary:obj]
                                           : obj;
                                       }], resp, nil);
                                   } else if ([object isKindOfClass:NSDictionary.class]) {
                                       callback([[class alloc] initWithValuesInDictionary:object], resp, nil);
                                   } else {
                                       callback(object, resp, nil);
                                   }
                               }];
        return nil;
    }];
}

+ (void)get:(NSString *)path class:(Class)class as:(SEL)sel
{
    [self routePath:path method:@"GET" class:class as:sel];
}

+ (void)post:(NSString *)path class:(Class)class as:(SEL)sel
{
    [self routePath:path method:@"POST" class:class as:sel];
}

+ (void)put:(NSString *)path class:(Class)class as:(SEL)sel
{
    [self routePath:path method:@"PUT" class:class as:sel];
}

+ (void)delete:(NSString *)path class:(Class)class as:(SEL)sel
{
    [self routePath:path method:@"DELETE" class:class as:sel];
}

@end