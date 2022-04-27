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
@property (weak) IBOutlet NSProgressIndicator *startWorkingIndicator;
@property (weak) IBOutlet NSProgressIndicator *stopWorkingIndicator;

@property (strong) NSNumber* cpuValue;
@property (strong) NSNumber* memoryValue;
@property (strong) NSNumber* diskValue;
@property BOOL useKubernetes;
@property (strong) NSString* containerRuntime;

@property bool isStarted;
@property bool isWorking;
@property (readonly) bool isStarting;
@property (readonly) bool isStopping;
@property (readonly) bool startMenuEnabled;
@property (readonly) bool stopMenuEnabled;



@property (weak) IBOutlet NSButton *okButton;

@property (strong) NSString* message;

@property (weak) IBOutlet NSView *homebrewDeployedLight;
@property (weak) IBOutlet NSButton *deployHomebrewButton;

@property (weak) IBOutlet NSView *colimaDeployedLight;
@property (weak) IBOutlet NSButton *deployColimaButton;
@property (weak) IBOutlet NSView *dockerDeployedLight;
@property (weak) IBOutlet NSButton *deployDockerButton;


@property (weak) IBOutlet NSView *portainerDeployedLight;
@property (weak) IBOutlet NSButton *deployPortainerButton;


@end

@implementation AppDelegate

@synthesize isStarted = _isStarted;
@synthesize isWorking = _isWorking;

dispatch_source_t _timer;
NSProgressIndicator* progressIndicator;

- (bool) getStartMenuEnabled {
    return !self.isStarted && !self.isWorking;
}

- (bool) stopMenuEnabled {
    return self.isStarted && !self.isWorking;
}
//
- (bool) getIsStarted {
    return !self.isStarted && self.isWorking;
}

- (bool) getIsStopping {
    return self.isStarted && self.isWorking;
}

- (bool) mustDisplayStartingMenuItem {
    return self.isStarting;
}

- (bool) mustDisplayStoppingMenuItem {
    return self.isStopping;
}

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
}

- (IBAction)deployPortainer:(id)sender {
    NSTask* task = [[NSTask alloc] init];
    NSError* err;
    NSString* dockerPath = [self dockerPath];
    NSString* command;
    
    if ( dockerPath == nil ) return;
    
    task.launchPath = @"/bin/zsh";
    command = [NSString stringWithFormat:@"%@ volume create portainer_data && %@ run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest", dockerPath, dockerPath];
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

- (IBAction)deployHomebrew:(id)sender {
    NSTask* task = [[NSTask alloc] init];
    NSError* err;
    NSString* dockerPath = [self dockerPath];
    NSString* command;
    
    if ( dockerPath == nil ) return;
    
    task.launchPath = @"/bin/zsh";
    command = [NSString stringWithFormat:@"/bin/bash \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""];
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

- (IBAction)deployColima:(id)sender {
    NSTask* task = [[NSTask alloc] init];
    NSError* err;
    NSString* dockerPath = [self dockerPath];
    NSString* command;
    
    if ( dockerPath == nil ) return;
    
    task.launchPath = @"/bin/zsh";
    command = [NSString stringWithFormat:@"brew install colima"];
    [task setArguments:[NSArray arrayWithObjects: @"-c", @"-l", command, nil]];
    
    self.deployColimaButton.enabled = NO;
    self.okButton.enabled = NO;
    
    [task setTerminationHandler:^(NSTask* _Nonnull task){
        dispatch_async(dispatch_get_main_queue(), ^{
            self.deployColimaButton.enabled = YES;
            self.okButton.enabled = YES;
            if ( task.terminationStatus != 0 ) {
                self.message = @"An Error happened";
            }
        });
    }];
    [task launchAndReturnError:&err];
}

- (IBAction)deployDocker:(id)sender {
    NSTask* task = [[NSTask alloc] init];
    NSError* err;
    NSString* dockerPath = [self dockerPath];
    NSString* command;
    
    if ( dockerPath == nil ) return;
    
    task.launchPath = @"/bin/zsh";
    command = [NSString stringWithFormat:@"brew install docker"];
    [task setArguments:[NSArray arrayWithObjects: @"-c", @"-l", command, nil]];
    
    self.deployDockerButton.enabled = NO;
    self.okButton.enabled = NO;
    
    [task setTerminationHandler:^(NSTask* _Nonnull task){
        dispatch_async(dispatch_get_main_queue(), ^{
            self.deployDockerButton.enabled = YES;
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
    [task setArguments:[NSArray arrayWithObjects: @"-c", @"-l", [NSString stringWithFormat:@"%@ status >/dev/null 2>&1", colimaPath], nil]];
    [task launchAndReturnError:&err];
    [task waitUntilExit];
    return task.terminationStatus == 0;
}

- (bool)executableIsDeployed:(NSString*)exec {
    NSTask* task = [[NSTask alloc] init];
    NSError* err;
    NSString* colimaPath = [self colimaPath];
    //colimaPath = @"/bin/zsh";
    if ( colimaPath == nil ) return NO;

    task.launchPath = @"/bin/zsh";
    [task setArguments:[NSArray arrayWithObjects: @"-c", @"-l", [NSString stringWithFormat:@"command -v %@ >/dev/null 2>&1 ", exec], nil]];
    [task launchAndReturnError:&err];
    [task waitUntilExit];
    return task.terminationStatus == 0;
}

- (bool)homebrewIsDeployed {
    return [self executableIsDeployed:@"brew"];
}

- (bool)colimaIsDeployed {
    return [self executableIsDeployed:@"colima"];
}

- (bool)portainerIsDeployed {
    //docker ps | grep portainer
    NSTask* task = [[NSTask alloc] init];
    NSError* err;
    NSString* colimaPath = [self colimaPath];
    //colimaPath = @"/bin/zsh";
    if ( colimaPath == nil ) return NO;

    task.launchPath = @"/bin/zsh";
    [task setArguments:[NSArray arrayWithObjects: @"-c", @"-l", @"docker ps | grep portainer >/dev/null 2>&1", nil]];
    [task launchAndReturnError:&err];
    [task waitUntilExit];
    return task.terminationStatus == 0;

}

- (bool)dockerIsDeployed {
    return [self executableIsDeployed:@"docker"];
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
    [task setTerminationHandler:^(NSTask* _Nonnull task){
        dispatch_async(dispatch_get_main_queue(), ^{
            //progressIndicator.hidden = YES;
            self.isWorking = NO;
        });
    }];
    self.isWorking = YES;
    //progressIndicator.hidden = NO;
    [task launchAndReturnError:&err];

    
}

- (NSProgressIndicator*) getProgressIndicator:(NSSize) size {
    if ( progressIndicator == nil ) {
        NSRect frame = NSMakeRect(0, 0, size.width, size.height);
        progressIndicator = [[NSProgressIndicator alloc] initWithFrame:frame];
        progressIndicator.indeterminate = YES;
        progressIndicator.style = NSProgressIndicatorStyleSpinning;
        progressIndicator.hidden = YES;
        [progressIndicator startAnimation:nil];
    }
    return progressIndicator;
}

- (IBAction)onStopMenuClick:(id)sender {
    NSTask* task = [[NSTask alloc] init];
    NSError* err;
    NSString* colimaPath = [self colimaPath];
    //colimaPath = @"/bin/zsh";
    if ( colimaPath == nil ) return;
    
    task.launchPath = @"/bin/zsh";
    [task setArguments:[NSArray arrayWithObjects: @"-c", @"-l", [NSString stringWithFormat:@"%@ stop", colimaPath], nil]];
    [task setTerminationHandler:^(NSTask* _Nonnull task){
        dispatch_async(dispatch_get_main_queue(), ^{
      //      progressIndicator.hidden = YES;
            self.isWorking = NO;
        });
    }];
    self.isWorking = YES;
    //progressIndicator.hidden = NO;
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
    
    [self.startWorkingIndicator startAnimation:nil];
    [self.stopWorkingIndicator startAnimation:nil];
    self.statusBar = [NSStatusBar systemStatusBar];// [[NSStatusBar alloc] init];
    
    self.statusItem = [self.statusBar statusItemWithLength:NSSquareStatusItemLength];
    
    NSImage* img = [NSImage imageNamed:@"MenuBarIcon"];
    img.size = NSMakeSize(18.0, 18.0);
    self.statusItem.button.image = img;
    self.statusItem.menu = self.statusMenu;
    
    [self.statusItem.button addSubview: [self getProgressIndicator: img.size]];
    
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    _timer = CreateTimerDispatchSource(1, queue, ^{
        self.isStarted = self.colimaIsStarted;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( self.homebrewIsDeployed ) {
                [self makeViewRound:self.homebrewDeployedLight andColored:NSColor.greenColor];
                self.deployHomebrewButton.enabled = NO;
            } else {
                [self makeViewRound:self.homebrewDeployedLight andColored:NSColor.redColor];
                self.deployHomebrewButton.enabled = YES;
            }
            if ( self.colimaIsDeployed ) {
                [self makeViewRound:self.colimaDeployedLight andColored:NSColor.greenColor];
                self.deployColimaButton.enabled = NO;
            } else {
                [self makeViewRound:self.colimaDeployedLight andColored:NSColor.redColor];
                self.deployColimaButton.enabled = YES;
            }
            if ( self.dockerIsDeployed ) {
                [self makeViewRound:self.dockerDeployedLight andColored:NSColor.greenColor];
                self.deployDockerButton.enabled = NO;
            } else {
                [self makeViewRound:self.dockerDeployedLight andColored:NSColor.redColor];
                self.deployDockerButton.enabled = YES;
            }
            if ( self.portainerIsDeployed ) {
                [self makeViewRound:self.portainerDeployedLight andColored:NSColor.greenColor];
                self.deployPortainerButton.enabled = NO;
            } else {
                [self makeViewRound:self.portainerDeployedLight andColored:NSColor.redColor];
                self.deployPortainerButton.enabled = YES;
            }
            
        });
        
    }) ;
    
    [self addObserver:self forKeyPath:@"isWorking" options:NSKeyValueObservingOptionNew context:nil];
    
    
    [self makeViewRound:self.homebrewDeployedLight andColored:NSColor.redColor];
    [self makeViewRound:self.colimaDeployedLight andColored:NSColor.redColor];
    [self makeViewRound:self.portainerDeployedLight andColored:NSColor.redColor];
    
    
}

- (void)makeViewRound:(NSView*)view andColored:(NSColor*)color {
    view.wantsLayer = YES;
    view.layer.cornerRadius = view.layer.frame.size.width / 2;
    view.layer.backgroundColor = color.CGColor;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{

    if ( [keyPath isEqualTo:@"isWorking"] ) {
        if ( self.isWorking ) {
            self.statusItem.button.image = [NSImage imageNamed:@"MenuBarIconOrange"];
            progressIndicator.hidden = NO;
        } else {
            self.statusItem.button.image = [NSImage imageNamed:@"MenuBarIcon"];
            progressIndicator.hidden = YES;
        }
        self.statusItem.button.image.size = NSMakeSize(18.0, 18.0);
    }
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
