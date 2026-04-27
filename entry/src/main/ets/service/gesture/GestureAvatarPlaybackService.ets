import { webview } from '@kit.ArkWeb'
import { AppConfig } from '../../common/constants/AppConfig'

/**
 * 数字人播放状态快照。
 */
export interface GestureAvatarPlaybackState {
  /** 数字人播放状态文案。 */
  avatarStatusText: string

  /** 数字人错误文案。 */
  avatarErrorText: string
}

/**
 * 数字人播放状态更新回调。
 */
type GestureAvatarPlaybackStateCallback = (state: GestureAvatarPlaybackState) => void

/**
 * 数字人播放会话服务。
 *
 * 职责：
 * 1. 持有 WebviewController；
 * 2. 管理数字人页面 ready 状态；
 * 3. 向数字人页面注入 SiGML 和运行时路径；
 * 4. 封装播放、重播、停止逻辑；
 * 5. 向页面回传数字人状态。
 */
export class GestureAvatarPlaybackService {
  /** 数字人 WebView 控制器。 */
  private avatarController: webview.WebviewController = new webview.WebviewController()

  /** 数字人页面是否加载完成。 */
  private avatarPageReady: boolean = false

  /** 数字人状态文案。 */
  private avatarStatusText: string = '数字人加载中'

  /** 数字人错误文案。 */
  private avatarErrorText: string = ''

  /** 状态更新回调。 */
  private onStateChange: GestureAvatarPlaybackStateCallback | null = null

  /**
   * 设置状态更新回调。
   *
   * @param callback 状态更新回调
   */
  setOnStateChange(callback: GestureAvatarPlaybackStateCallback): void {
    this.onStateChange = callback
  }

  /**
   * 获取数字人 WebView 控制器。
   *
   * @returns WebView 控制器
   */
  getController(): webview.WebviewController {
    return this.avatarController
  }

  /**
   * 标记数字人页面加载完成。
   *
   * @param sigmlUrl 当前动作 SiGML 地址
   */
  handlePageEnd(sigmlUrl: string): void {
    this.avatarPageReady = true
    this.avatarStatusText = sigmlUrl === '' ? '当前资源没有可播放的 SiGML 文件' : '数字人已就绪'
    this.emitState()
    void this.syncAvatar(sigmlUrl, false)
  }

  /**
   * 标记页面不可用。
   */
  markPageNotReady(): void {
    this.avatarPageReady = false
  }

  /**
   * 播放数字人示范。
   *
   * @param sigmlUrl 当前动作 SiGML 地址
   */
  async play(sigmlUrl: string): Promise<void> {
    await this.syncAvatar(sigmlUrl, true)
  }

  /**
   * 重新播放数字人示范。
   *
   * @param sigmlUrl 当前动作 SiGML 地址
   */
  async replay(sigmlUrl: string): Promise<void> {
    if (!this.avatarPageReady) {
      this.avatarStatusText = '数字人画面还在加载'
      this.emitState()
      return
    }

    if (sigmlUrl === '') {
      this.avatarStatusText = '当前资源没有可播放的 SiGML 文件'
      this.emitState()
      return
    }

    try {
      await this.avatarController.runJavaScript("window.replayCurrentSign && window.replayCurrentSign(); 'ok';")
      this.avatarErrorText = ''
      this.avatarStatusText = '数字人已重新播放'
      this.emitState()
    } catch (err) {
      this.avatarErrorText = `重播数字人失败：${JSON.stringify(err)}`
      this.avatarStatusText = '数字人重播失败'
      console.error(this.avatarErrorText)
      this.emitState()
    }
  }

  /**
   * 停止数字人播放。
   */
  async stop(): Promise<void> {
    if (!this.avatarPageReady) {
      return
    }

    try {
      await this.avatarController.runJavaScript("window.stopCurrentSign && window.stopCurrentSign(); 'ok';")
    } catch (err) {
      console.error(`停止数字人播放失败：${JSON.stringify(err)}`)
    }
  }

  /**
   * 同步数字人配置并按需播放。
   *
   * @param sigmlUrl 当前动作 SiGML 地址
   * @param playNow 是否立即播放
   */
  private async syncAvatar(sigmlUrl: string, playNow: boolean): Promise<void> {
    if (!this.avatarPageReady) {
      this.avatarStatusText = '数字人画面还在加载'
      this.emitState()
      return
    }

    if (sigmlUrl === '') {
      this.avatarStatusText = '当前资源没有可播放的 SiGML 文件'
      this.emitState()
      return
    }

    try {
      await this.avatarController.runJavaScript(this.buildAvatarBootstrapScript(sigmlUrl, playNow))
      this.avatarErrorText = ''
      this.avatarStatusText = playNow ? '数字人正在播放' : '数字人已就绪'
      this.emitState()
    } catch (err) {
      this.avatarErrorText = `同步数字人配置失败：${JSON.stringify(err)}`
      this.avatarStatusText = '数字人加载失败'
      console.error(this.avatarErrorText)
      this.emitState()
    }
  }

  /**
   * 构建数字人页面初始化脚本。
   *
   * @param sigmlUrl 当前动作 SiGML 地址
   * @param playNow 是否立即播放
   * @returns JavaScript 脚本
   */
  private buildAvatarBootstrapScript(sigmlUrl: string, playNow: boolean): string {
    const payload = JSON.stringify({
      sigmlUrl: sigmlUrl,
      cwaBase: AppConfig.buildRuntimeBaseUrl(),
      sigmlBase: AppConfig.buildDemoSigmlBaseUrl(),
      avJARBase: AppConfig.buildAvatarJarBaseUrl()
    })

    const playScript = playNow ? "window.playCurrentSign && window.playCurrentSign();" : ''
    return `window.setAvatarConfig && window.setAvatarConfig(${payload}); ${playScript} 'ok';`
  }

  /**
   * 向页面同步状态。
   */
  private emitState(): void {
    if (this.onStateChange === null) {
      return
    }

    this.onStateChange({
      avatarStatusText: this.avatarStatusText,
      avatarErrorText: this.avatarErrorText
    })
  }
}
