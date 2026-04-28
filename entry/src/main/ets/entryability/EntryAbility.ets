import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { restoreAuthState } from '../common/auth/AuthStorage';

const DOMAIN = 0x0000;
const TAG = 'HearBridgeEntry';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');
    this.restoreAuthStateBeforeLoad(windowStage);
  }

  /**
   * 加载首页前恢复本地登录态。
   *
   * 说明：
   * 1. HttpClient 自动带 token 时读取的是 AppStorage 中的 auth.token。
   * 2. App 冷启动后必须先从 preferences 恢复到 AppStorage。
   * 3. 日志只输出 token 长度，不输出 token 原文。
   *
   * @param windowStage 当前窗口 Stage
   */
  private async restoreAuthStateBeforeLoad(windowStage: window.WindowStage): Promise<void> {
    try {
      await restoreAuthState(this.context);
      const token = AppStorage.get('auth.token') as string | undefined;

      hilog.info(
        DOMAIN,
        TAG,
        'Auth state restored before loadContent. tokenLength=%{public}d',
        token ? token.length : 0
      );
    } catch (err) {
      hilog.error(
        DOMAIN,
        TAG,
        'Failed to restore auth state. Cause: %{public}s',
        JSON.stringify(err)
      );
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}