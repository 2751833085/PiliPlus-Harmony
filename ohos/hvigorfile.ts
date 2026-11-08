import path from 'path'
import fs from 'fs'
import { hvigor } from '@ohos/hvigor';
import { appTasks, OhosAppContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin';
import { flutterHvigorPlugin } from 'flutter-hvigor-plugin';

// Flutter OH strips prerelease text before generating app.json5. Restore the
// package version after all plugin evaluation hooks, before packaging/signing.
hvigor.nodesEvaluated(() => {
    const rootNode = hvigor.getRootNode();
    const pubspec = fs.readFileSync(path.join(path.dirname(__dirname), 'pubspec.yaml'), 'utf8');
    const version = pubspec.match(/^version:\s*(\d+\.\d+\.\d+(?:-beta)?)\+(\d+)\s*$/m);
    if (!version) throw new Error('Expected pubspec version name+build');
    const context = rootNode.getContext(OhosPluginId.OHOS_APP_PLUGIN) as OhosAppContext;
    const config = context.getAppJsonOpt();
    config.app.versionName = version[1];
    config.app.versionCode = Number(version[2]);
    context.setAppJsonOpt(config);
});

export default {
    system: appTasks,  /* Built-in plugin of Hvigor. It cannot be modified. */
    plugins:[flutterHvigorPlugin(path.dirname(__dirname))]         /* Custom plugin to extend the functionality of Hvigor. */
}