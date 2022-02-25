//
//  AppDelegate.m
//  ColimaGUI
//
//  Created by Jean-Philippe Alexandre on 24/02/2022.
//

#import "AppDelegate.h"
#import <libproc.h>

@interface AppDelegate ()

@property (strong) NSStatusBar *statusBar;
@property (strong) NSStatusItem *statusItem;
@property (strong) IBOutlet NSMenu* statusMenu;

@property (weak) IBOutlet NSTextField *cpuTextField;
@property (weak) IBOutlet NSTextField *memoryTextField;
@property (weak) IBOutlet NSSlider *diskSlider;
@property (weak) IBOutlet NSWindow *settingsWindow;
@property (weak) IBOutlet NSSwitch *kubernetesSwitch;
@property (weak) IBOutlet NSPopUpButton *runtimeDropDown;

@property (strong) NSNumber* cpuValue;
@property (strong) NSNumber* memoryValue;
@property (strong) NSNumber* diskValue;
@property BOOL useKubernetes;
@property (strong) NSString* containerRuntime;

@property (readonly) bool isStarted;

@property (weak) IBOutlet NSButton *deployPortainerButton;
@property (weak) IBOutlet NSButton *okButton;

@property (strong) NSString* message;

@end

@implementation AppDelegate

@synthesize isStarted = _isStarted;

dispatch_source_t _timer;

- (NSNumber*) cpuCount {
    NSProcessInfo* info = NSProcessInfo.processInfo;
    return @(info.processorCount);
}

- (NSNumber*) memoryCount {
    NSProcessInfo* info = NSProcessInfo.processInfo;
    return @(info.physicalMemory / 1073741824);
}


- (NSString*) pathForApp:(NSString*) app {
    NSTask* task = [[NSTask alloc] init];
    NSError* err;
    task.launchPath = @"/bin/zsh";
    task.arguments = [NSArray arrayWithObjects: @"-c", @"-l", [NSString stringWithFormat:@"/usr/bin/which %@", app], nil];
    
    NSPipe *outPipe =  [[NSPipe alloc] init];
    [task setStandardOutput:outPipe];
    [task launchAndReturnError:&err];

    NSData *data = [[outPipe fileHandleForReading] readDataToEndOfFile];
    NSString *path = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];

    
    if ( path == nil || path.length == 0 ) return nil;
    path = [path stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\n"]];

    return path;
}

- (NSString*) dockerPath {
    return [self pathForApp:@"docker"];
}

- (NSString*) colimaPath {
    return [self pathForApp:@"colima"];
    
}

- (IBAction)onDashboardMenuClick:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL  URLWithString:@"https://localhost:9443/"]];
    //NSURL* url2 = [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:url];
    //NSLog(@"%@", url2);
}

- (IBAction)deployPortainer:(id)sender {
    NSTask* task = [[NSTask alloc] init];
    NSError* err;
    NSString* dockerPath = [self dockerPath];
    NSString* command;
    
    if ( dockerPath == nil ) return;
    
    task.launchPath = @"/bin/zsh";
    command = [NSString stringWithFormat:@"%@ volume create portainer_data2 && %@ run -d -p 8001:8000 -p 9444:9443 --name portainer1 --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data2:/data portainer/portainer-ce:latest", dockerPath, dockerPath];
    [task setArguments:[NSArray arrayWithObjects: @"-c", @"-l", command, nil]];
    
    self.deployPortainerButton.enabled = NO;
    self.okButton.enabled = NO;
    
    [task setTerminationHandler:^(NSTask* _Nonnull task){
        dispatch_async(dispatch_get_main_queue(), ^{
            self.deployPortainerButton.enabled = YES;
            self.okButton.enabled = YES;
            if ( task.terminationStatus != 0 ) {
                self.message = @"An Error happened";
            }
        });
    }];
    [task launchAndReturnError:&err];
    
    
}

- (bool)colimaIsStarted {
    NSTask* task = [[NSTask alloc] init];
    NSError* err;
    NSString* colimaPath = [self colimaPath];
    //colimaPath = @"/bin/zsh";
    if ( colimaPath == nil ) return NO;

    task.launchPath = @"/bin/zsh";
    [task setArguments:[NSArray arrayWithObjects: @"-c", @"-l", [NSString stringWithFormat:@"%@ status", colimaPath], nil]];
    [task launchAndReturnError:&err];
    [task waitUntilExit];
    return task.terminationStatus == 0;
}

- (IBAction)onQuitMenuClick:(id)sender {
    [[NSApplication sharedApplication] terminate:sender];
}

- (IBAction)onStartMenuClick:(id)sender {
    NSTask* task = [[NSTask alloc] init];
    NSError* err;
    NSString* colimaPath = [self colimaPath];
    //colimaPath = @"/bin/zsh";
    if ( colimaPath == nil ) return;
    
    task.launchPath = @"/bin/zsh";
    [task setArguments:[NSArray arrayWithObjects:
                        @"-c",
                        @"-l",
                        [NSString stringWithFormat:@"%@ start -c %d -m %d -d %d %@ -r %@",
                         colimaPath,
                        self.cpuValue.intValue,
                         self.memoryValue.intValue,
                         self.diskValue.intValue,
                         self.useKubernetes ? @"-k" : @"",
                         self.containerRuntime
                        ],
                        
                        nil]];
    [task launchAndReturnError:&err];

    
}

- (IBAction)onStopMenuClick:(id)sender {
    NSTask* task = [[NSTask alloc] init];
    NSError* err;
    NSString* colimaPath = [self colimaPath];
    //colimaPath = @"/bin/zsh";
    if ( colimaPath == nil ) return;
    
    task.launchPath = @"/bin/zsh";
    [task setArguments:[NSArray arrayWithObjects: @"-c", @"-l", [NSString stringWithFormat:@"%@ stop", colimaPath], nil]];
    [task launchAndReturnError:&err];
}

- (IBAction)onSettingsMenuClick:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [self.settingsWindow makeKeyAndOrderFront:self];
    [self.settingsWindow setIsVisible:YES];
    self.statusItem.button.enabled = NO;
}

- (IBAction)onRestartMenuClick:(id)sender {
    [self onStopMenuClick:sender];
    [self onStartMenuClick:sender];
}

- (IBAction)onOkSettingsClick:(id)sender {
    [self.settingsWindow orderOut:self];
    self.statusItem.button.enabled = YES;
    NSNumber* currentCpu = self.cpuValue;
    NSNumber* currentMemory = self.memoryValue;
    NSNumber* currentDisk = self.diskValue;
    BOOL currentUseKubernetes = self.useKubernetes;
    NSString* currentRuntime = self.containerRuntime;
    
    self.cpuValue = @(self.cpuTextField.integerValue);
    self.memoryValue = @(self.memoryTextField.integerValue);
    self.diskValue = @(self.diskSlider.integerValue);
    self.useKubernetes = self.kubernetesSwitch.state;
    self.containerRuntime = self.runtimeDropDown.titleOfSelectedItem;
    
    bool changed = ![self.cpuValue isEqualToNumber:currentCpu] || ![self.memoryValue isEqualToNumber:currentMemory] || ![self.diskValue isEqualToNumber:currentDisk] || currentUseKubernetes != self.useKubernetes || ![currentRuntime isEqualTo:self.containerRuntime];
    
    [self persisSettings];
    
    if ( changed ) {
        [self onRestartMenuClick:sender];
    }
}

- (IBAction)onCancelSettingsClick:(id)sender {
    [self.settingsWindow orderOut:self];
    self.statusItem.button.enabled = YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    [self loadSettings];
    
    self.statusBar = [NSStatusBar systemStatusBar];// [[NSStatusBar alloc] init];
    
    self.statusItem = [self.statusBar statusItemWithLength:NSSquareStatusItemLength];
    
    NSImage* img = [NSImage imageNamed:@"MenuBarIcon"];
    img.size = NSMakeSize(18.0, 18.0);
    img.template = YES;
    self.statusItem.button.image = img;
    self.statusItem.menu = self.statusMenu;
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    _timer = CreateTimerDispatchSource(1, queue, ^{
//        int n = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
//        int *buffer = (int *)malloc(sizeof(int)*n);
//        n = proc_listpids(PROC_ALL_PIDS, 0, buffer, n*sizeof(int));
//
//        int i;
//        for(i = 0; i < n; i++) {
//            pid_t pid = buffer[i];
//            if ( pid == 0 ) continue;
//            char path[PROC_PIDPATHINFO_MAXSIZE];
//            proc_pidpath(pid, path, sizeof(path));
//            NSLog(@"(%d) %s",pid, path);
//            if ( strstr(path, "colima") ) {
//                NSLog(@"We found colima running");
//                break;
//            }
//        }
//        NSLog(@"----------------");
        self->_isStarted = self.colimaIsStarted;

    }) ;
    
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    if ( _timer != nil ) {
        dispatch_source_cancel(_timer);
    }
}


- (void) loadSettings {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    self.cpuValue =  [defaults objectForKey:@"cpu"] == nil ? @2 : @( [defaults integerForKey:@"cpu"]);
    self.memoryValue = [defaults objectForKey:@"memory"] == nil ? @4 : @([defaults integerForKey:@"memory"]);
    self.diskValue = @(1024 * 1024 * 1024 * ([defaults objectForKey:@"disk"] == nil ? 60 : [defaults integerForKey:@"disk"]));
    self.useKubernetes = [defaults objectForKey:@"useKubernetes"] == nil ? NO : [defaults boolForKey:@"useKubernetes"];
    self.containerRuntime = [defaults objectForKey:@"containerRuntime"] == nil ? @"docker" : [defaults objectForKey:@"containerRuntime"];
}
- (void) persisSettings {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:self.cpuValue.integerValue forKey:@"cpu"];
    [defaults setInteger:self.memoryValue.integerValue forKey:@"memory"];
    [defaults setInteger:(self.diskValue.integerValue / (1024 * 1024 * 1024)) forKey:@"disk"];
    [defaults setBool:self.useKubernetes forKey:@"useKubernetes"];
    [defaults setObject:self.containerRuntime forKey:@"containerRuntime"];
    
    [defaults synchronize];
}


dispatch_source_t CreateTimerDispatchSource(uint64_t interval, dispatch_queue_t queue, dispatch_block_t block)
{
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);

    if (timer)
    {
        dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), (int64_t) interval * NSEC_PER_SEC, 0);
        dispatch_source_set_event_handler(timer, block);
        dispatch_resume(timer);
    }

    return timer;
}

@end
