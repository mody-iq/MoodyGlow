- (void)removeNotificationWithID:(NSString *)identifier {
    if (!identifier || identifier.length == 0) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL existed = (self.map[identifier] != nil);
        [self.map removeObjectForKey:identifier];
        NSArray *apps = [self uniqueBundleIDs];
        [self writeLog:[NSString stringWithFormat:@"REMOVE %@ | existed=%d | total=%lu | uniqueApps=%lu",
                        identifier,
                        existed,
                        (unsigned long)self.map.count,
                        (unsigned long)apps.count]];
    });
}
