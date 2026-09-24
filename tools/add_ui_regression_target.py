"""Add the UI regression target in CI without dependencies beyond Xcode and Python."""
import json, plistlib, subprocess
from pathlib import Path
from xml.etree import ElementTree as ET
project = Path('SarahIA/SarahIA.xcodeproj')
path = project / 'project.pbxproj'
data = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))
o = data['objects']; root = o[data['rootObject']]
app_id = next(k for k,v in o.items() if v.get('isa') == 'PBXNativeTarget' and v.get('name') == 'SarahIA')
def add(n, **values):
    key = f'FEE10000000000000000{n:04X}'
    o[key] = values
    return key
file = add(1, isa='PBXFileReference', lastKnownFileType='sourcecode.swift', path='SarahUIRegression/NavigationTests.swift', sourceTree='<group>')
o[root['mainGroup']]['children'].append(file)
product = add(2, isa='PBXFileReference', explicitFileType='wrapper.cfbundle', path='SarahUIRegression.xctest', sourceTree='BUILT_PRODUCTS_DIR')
o[root['productRefGroup']]['children'].append(product)
build = add(3, isa='PBXBuildFile', fileRef=file)
sources = add(4, isa='PBXSourcesBuildPhase', buildActionMask=2147483647, files=[build], runOnlyForDeploymentPostprocessing=0)
frameworks = add(5, isa='PBXFrameworksBuildPhase', buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
configs=[]
for i,name in enumerate(['Debug', 'Release']):
    configs.append(add(6+i, isa='XCBuildConfiguration', name=name, buildSettings={
        'PRODUCT_BUNDLE_IDENTIFIER':'com.sarahia.app.uitests', 'PRODUCT_NAME':'$(TARGET_NAME)',
        'SWIFT_VERSION':'5.0','GENERATE_INFOPLIST_FILE':'YES','IPHONEOS_DEPLOYMENT_TARGET':'16.2',
        'TARGETED_DEVICE_FAMILY':'1,2', 'TEST_TARGET_NAME':'SarahIA', 'SDKROOT':'iphoneos',
        'CODE_SIGNING_ALLOWED':'NO','SUPPORTED_PLATFORMS':'iphonesimulator iphoneos'}))
config=add(8, isa='XCConfigurationList', buildConfigurations=configs, defaultConfigurationIsVisible=0, defaultConfigurationName='Debug')
proxy=add(9, isa='PBXContainerItemProxy', containerPortal=data['rootObject'], proxyType=1, remoteGlobalIDString=app_id, remoteInfo='SarahIA')
dep=add(10, isa='PBXTargetDependency', target=app_id, targetProxy=proxy)
target=add(11, isa='PBXNativeTarget', name='SarahUIRegression', productName='SarahUIRegression', productType='com.apple.product-type.bundle.ui-testing', productReference=product, buildConfigurationList=config, buildPhases=[sources,frameworks], buildRules=[], dependencies=[dep])
root['targets'].append(target)
root['attributes'].setdefault('TargetAttributes',{})[target]={'CreatedOnToolsVersion':'16.0','TestTargetID':app_id}
# App-hosted tests exercise the real view model and stale audio callbacks.
unit_file=add(20, isa='PBXFileReference', lastKnownFileType='sourcecode.swift', path='SarahUIRegression/AudioLifecycleTests.swift', sourceTree='<group>')
o[root['mainGroup']]['children'].append(unit_file)
unit_product=add(21, isa='PBXFileReference', explicitFileType='wrapper.cfbundle', path='SarahAudioRegression.xctest', sourceTree='BUILT_PRODUCTS_DIR')
o[root['productRefGroup']]['children'].append(unit_product)
unit_build=add(22, isa='PBXBuildFile', fileRef=unit_file)
unit_sources=add(23, isa='PBXSourcesBuildPhase', buildActionMask=2147483647, files=[unit_build], runOnlyForDeploymentPostprocessing=0)
unit_frameworks=add(24, isa='PBXFrameworksBuildPhase', buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
unit_configs=[]
for i,name in enumerate(['Debug','Release']):
    unit_configs.append(add(25+i, isa='XCBuildConfiguration', name=name, buildSettings={
        'PRODUCT_BUNDLE_IDENTIFIER':'com.sarahia.app.audiotests','PRODUCT_NAME':'$(TARGET_NAME)',
        'SWIFT_VERSION':'5.0','GENERATE_INFOPLIST_FILE':'YES','IPHONEOS_DEPLOYMENT_TARGET':'16.2',
        'SDKROOT':'iphoneos','CODE_SIGNING_ALLOWED':'NO','SUPPORTED_PLATFORMS':'iphonesimulator iphoneos',
        'TEST_HOST':'$(BUILT_PRODUCTS_DIR)/SarahIA.app/SarahIA','BUNDLE_LOADER':'$(TEST_HOST)',
        'LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/Frameworks','@loader_path/Frameworks']}))
unit_config=add(27, isa='XCConfigurationList', buildConfigurations=unit_configs, defaultConfigurationIsVisible=0, defaultConfigurationName='Debug')
unit_dep=add(28, isa='PBXTargetDependency', target=app_id, targetProxy=proxy)
unit_target=add(29, isa='PBXNativeTarget', name='SarahAudioRegression', productName='SarahAudioRegression', productType='com.apple.product-type.bundle.unit-test', productReference=unit_product, buildConfigurationList=unit_config, buildPhases=[unit_sources,unit_frameworks], buildRules=[], dependencies=[unit_dep])
root['targets'].append(unit_target)
for config_id in o[o[app_id]['buildConfigurationList']]['buildConfigurations']:
    if o[config_id]['name']=='Debug': o[config_id]['buildSettings']['ENABLE_TESTABILITY']='YES'
path.write_bytes(plistlib.dumps(data))
scheme=ET.Element('Scheme', version='1.3', LastUpgradeVersion='1600')
def ref(parent,id,name,buildname):
    ET.SubElement(parent,'BuildableReference',BuildableIdentifier='primary',BlueprintIdentifier=id,BuildableName=buildname,BlueprintName=name,ReferencedContainer='container:SarahIA.xcodeproj')
action=ET.SubElement(scheme,'BuildAction',parallelizeBuildables='YES',buildImplicitDependencies='YES')
entries=ET.SubElement(action,'BuildActionEntries')
for id,name,buildname in [(app_id,'SarahIA','SarahIA.app'),(target,'SarahUIRegression','SarahUIRegression.xctest'),(unit_target,'SarahAudioRegression','SarahAudioRegression.xctest')]:
    e=ET.SubElement(entries,'BuildActionEntry',buildForTesting='YES',buildForRunning='YES',buildForProfiling='NO',buildForArchiving='NO',buildForAnalyzing='YES');ref(e,id,name,buildname)
test=ET.SubElement(scheme,'TestAction',buildConfiguration='Debug',selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB',selectedLauncherIdentifier='Xcode.IDEFoundation.Launcher.LLDB',shouldUseLaunchSchemeArgsEnv='YES')
tests=ET.SubElement(test,'Testables'); t=ET.SubElement(tests,'TestableReference',skipped='NO');ref(t,target,'SarahUIRegression','SarahUIRegression.xctest')
t=ET.SubElement(tests,'TestableReference',skipped='NO');ref(t,unit_target,'SarahAudioRegression','SarahAudioRegression.xctest')
ET.ElementTree(scheme).write(project/'xcshareddata/xcschemes/SarahUIRegression.xcscheme',encoding='utf-8',xml_declaration=True)
