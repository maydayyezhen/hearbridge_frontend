import { router, window, display } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { camera } from '@kit.CameraKit'
import { BusinessError } from '@kit.BasicServicesKit'
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl'
import { GesturePracticePageParams } from '../model/GestureModels'

@Entry
@Component
struct GesturePracticePage {
  @State gestureId: number = 0
  @State chineseName: string = ''
  @State label: string = ''

  @State showCameraOverlay: boolean = false
  @State surfaceId: string = ''
  @State cameraStatusText: string = '等待打开相机'
  @State previewStarted: boolean = false

  // 预览区域显示比例（宽 / 高），默认先给一个竖屏值
  @State previewAspectRatio: number = 9 / 16

  // 相机层自己的安全区内边距
  @State topSafeInsetVp: number = 0
  @State bottomSafeInsetVp: number = 0

  // XComponent 控制器
  private xComponentController: XComponentController = new XComponentController()

  // 相机相关对象
  private cameraManager?: camera.CameraManager
  private currentCamera?: camera.CameraDevice
  private currentCameraInput?: camera.CameraInput
  private currentPreviewOutput?: camera.PreviewOutput
  private currentSession?: camera.PhotoSession

  // 避免重复启动
  private isCameraStarting: boolean = false

  aboutToAppear(): void {
    this.readParams()
  }

  aboutToDisappear(): void {
    this.safeStopCamera()
  }

  /**
   * 读取路由参数
   */
  private readParams(): void {
    try {
      const params = router.getParams() as GesturePracticePageParams
      if (params) {
        this.gestureId = Number(params.gestureId)
        this.chineseName = String(params.chineseName)
        this.label = String(params.label)
      }
    } catch (err) {
      console.error(`读取训练页参数失败：${JSON.stringify(err)}`)
    }
  }

  /**
   * 返回上一页
   */
  private goBack(): void {
    try {
      router.back()
    } catch (err) {
      console.error(`返回手势列表页失败：${JSON.stringify(err)}`)
    }
  }


  /**
   * 运行时申请相机权限
   */
  private async requestCameraPermission(): Promise<boolean> {
    const context = getContext(this) as common.UIAbilityContext
    const atManager = abilityAccessCtrl.createAtManager()
    const permissions: Array<Permissions> = ['ohos.permission.CAMERA']

    try {
      const result = await atManager.requestPermissionsFromUser(context, permissions)
      if (!result || !result.authResults || result.authResults.length === 0) {
        return false
      }
      return result.authResults.every((item: number) => item === 0)
    } catch (error) {
      const err = error as BusinessError
      console.error(`申请相机权限失败：code=${err.code}, message=${err.message}`)
      return false
    }
  }

  /**
   * 选择一个可用摄像头，优先前置
   */
  private pickCameraDevice(cameraList: Array<camera.CameraDevice>): camera.CameraDevice | undefined {
    if (!cameraList || cameraList.length === 0) {
      return undefined
    }

    for (let i = 0; i < cameraList.length; i++) {
      if (cameraList[i].cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT) {
        return cameraList[i]
      }
    }

    return cameraList[0]
  }

  /**
   * XComponent 加载完成后，拿到 surfaceId 并启动相机
   */
  private async handleSurfaceLoaded(): Promise<void> {
    try {
      this.surfaceId = this.xComponentController.getXComponentSurfaceId()
      console.info(`相机预览 surfaceId：${this.surfaceId}`)
      await this.startRealCamera()
    } catch (error) {
      const err = error as BusinessError
      this.cameraStatusText = `获取预览面失败：${err.code}`
      console.error(`获取 surfaceId 失败：code=${err.code}, message=${err.message}`)
    }
  }

  /**
   * 启动真实相机预览
   */
  private async startRealCamera(): Promise<void> {
    if (this.isCameraStarting) {
      return
    }
    if (!this.surfaceId) {
      this.cameraStatusText = '预览面尚未就绪'
      return
    }

    this.isCameraStarting = true
    this.previewStarted = false
    this.cameraStatusText = '正在申请相机权限'

    try {
      const granted = await this.requestCameraPermission()
      if (!granted) {
        this.cameraStatusText = '未获得相机权限'
        return
      }

      // 避免重复打开时旧会话残留
      await this.safeStopCamera()

      const context = getContext(this) as common.UIAbilityContext

      // 1. 获取 CameraManager
      this.cameraManager = camera.getCameraManager(context)

      // 2. 获取可用摄像头
      const cameraList: Array<camera.CameraDevice> = this.cameraManager.getSupportedCameras()
      if (!cameraList || cameraList.length === 0) {
        this.cameraStatusText = '未找到可用摄像头'
        return
      }

      this.currentCamera = this.pickCameraDevice(cameraList)
      if (!this.currentCamera) {
        this.cameraStatusText = '摄像头选择失败'
        return
      }

      const outputCapability: camera.CameraOutputCapability =
        this.cameraManager.getSupportedOutputCapability(this.currentCamera, camera.SceneMode.NORMAL_PHOTO)

      if (!outputCapability.previewProfiles || outputCapability.previewProfiles.length === 0) {
        this.cameraStatusText = '当前设备没有可用预览配置'
        return
      }

      // 选一个比例最接近当前窗口的 profile
      const previewProfile = await this.pickBestPreviewProfile(outputCapability.previewProfiles)

      // 更新预览显示比例（竖屏宽 / 高）
      this.previewAspectRatio = this.getPortraitRatioOfProfile(previewProfile)

      // 让 XComponent 持有的 surface 尺寸与预览 profile 一致
      this.xComponentController.setXComponentSurfaceSize({
        surfaceWidth: previewProfile.size.width,
        surfaceHeight: previewProfile.size.height
      })

      this.currentCameraInput = this.cameraManager.createCameraInput(this.currentCamera)
      await this.currentCameraInput.open()

      this.currentPreviewOutput = this.cameraManager.createPreviewOutput(previewProfile, this.surfaceId)

      this.currentPreviewOutput.on('frameStart', () => {
        this.previewStarted = true
        this.cameraStatusText = '预览已启动'
      })

      this.currentPreviewOutput.on('error', (previewError: BusinessError) => {
        this.cameraStatusText = `预览出错：${previewError.code}`
        console.error(`预览输出错误：code=${previewError.code}, message=${previewError.message}`)
      })

      this.currentSession = this.cameraManager.createSession(camera.SceneMode.NORMAL_PHOTO) as camera.PhotoSession
      this.currentSession.beginConfig()
      this.currentSession.addInput(this.currentCameraInput)
      this.currentSession.addOutput(this.currentPreviewOutput)
      await this.currentSession.commitConfig()

      // 提交配置后，根据当前屏幕方向设置预览旋转
      const displayRotation = display.getDefaultDisplaySync().rotation * camera.ImageRotation.ROTATION_90
      const previewRotation = this.currentPreviewOutput.getPreviewRotation(displayRotation)
      this.currentPreviewOutput.setPreviewRotation(previewRotation, false)

      this.cameraStatusText = '正在启动预览'
      await this.currentSession.start()
    } catch (error) {
      const err = error as BusinessError
      this.cameraStatusText = `相机启动失败：${err.code}`
      console.error(`启动真实相机失败：code=${err.code}, message=${err.message}`)
    } finally {
      this.isCameraStarting = false
    }
  }

  /**
   * 安全停止相机
   */
  private async safeStopCamera(): Promise<void> {
    try {
      if (this.currentSession) {
        await this.currentSession.stop()
      }
    } catch (error) {
      const err = error as BusinessError
      console.error(`停止会话失败：code=${err.code}, message=${err.message}`)
    }

    try {
      if (this.currentPreviewOutput) {
        this.currentPreviewOutput.release()
      }
    } catch (error) {
      const err = error as BusinessError
      console.error(`释放预览输出失败：code=${err.code}, message=${err.message}`)
    }

    try {
      if (this.currentCameraInput) {
        this.currentCameraInput.close()
      }
    } catch (error) {
      const err = error as BusinessError
      console.error(`关闭相机输入失败：code=${err.code}, message=${err.message}`)
    }

    this.currentSession = undefined
    this.currentPreviewOutput = undefined
    this.currentCameraInput = undefined
    this.currentCamera = undefined
    this.cameraManager = undefined
    this.previewStarted = false
  }

  /**
   * 获取当前窗口的目标竖屏宽高比（宽 / 高）
   */
  private async getTargetPortraitRatio(): Promise<number> {
    const context = getContext(this) as common.UIAbilityContext
    const win = await window.getLastWindow(context)
    const rect = win.getWindowProperties().windowRect
    return rect.width / rect.height
  }

  /**
   * 将 profile 的尺寸换算成竖屏显示时的宽高比（宽 / 高）
   */
  private getPortraitRatioOfProfile(profile: camera.Profile): number {
    const width = profile.size.width
    const height = profile.size.height
    const shortSide = Math.min(width, height)
    const longSide = Math.max(width, height)
    return shortSide / longSide
  }

  /**
   * 选一个和当前窗口比例最接近的预览 profile
   */
  private async pickBestPreviewProfile(profiles: Array<camera.Profile>): Promise<camera.Profile> {
    const targetRatio = await this.getTargetPortraitRatio()
    let bestProfile: camera.Profile = profiles[0]
    let bestDiff: number = Number.MAX_VALUE

    for (let i = 0; i < profiles.length; i++) {
      const currentRatio = this.getPortraitRatioOfProfile(profiles[i])
      const diff = Math.abs(currentRatio - targetRatio)
      if (diff < bestDiff) {
        bestDiff = diff
        bestProfile = profiles[i]
      }
    }

    return bestProfile
  }

  /**
   * 切换窗口沉浸式布局，并读取上下避让区高度
   */
  private async updateWindowImmersive(enable: boolean): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext
    const win = await window.getLastWindow(context)

    await win.setWindowLayoutFullScreen(enable)

    if (enable) {
      const systemArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      const navArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)

      this.topSafeInsetVp = px2vp(systemArea.topRect.height)
      this.bottomSafeInsetVp = px2vp(navArea.bottomRect.height)
    } else {
      this.topSafeInsetVp = 0
      this.bottomSafeInsetVp = 0
    }
  }

  /**
   * 获取顶部悬浮区 padding，避免被状态栏压住
   */
  private getOverlayTopPadding(): number {
    return (this.topSafeInsetVp > 0 ? this.topSafeInsetVp : 32) + 8
  }

  /**
   * 获取底部悬浮区 padding，避免贴到底部手势条
   */
  private getOverlayBottomPadding(): number {
    return (this.bottomSafeInsetVp > 0 ? this.bottomSafeInsetVp : 24) + 16
  }

  private async openCameraOverlay(): Promise<void> {
    this.cameraStatusText = '等待创建预览面'
    this.previewStarted = false
    await this.updateWindowImmersive(true)
    this.showCameraOverlay = true
  }

  private async closeCameraOverlay(): Promise<void> {
    await this.safeStopCamera()
    this.showCameraOverlay = false
    this.surfaceId = ''
    this.previewStarted = false
    this.cameraStatusText = '等待打开相机'
    await this.updateWindowImmersive(false)
  }

  /**
   * 顶部栏
   */
  @Builder
  private buildTopBar(): void {
    Row() {
      Button('返回')
        .fontSize(16)
        .height(40)
        .backgroundColor('#F3F4F6')
        .fontColor('#222222')
        .borderRadius(20)
        .onClick(() => {
          this.goBack()
        })

      Text('手势训练')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ left: 16 })

      Blank()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 12 })
    .backgroundColor('#FFFFFF')
  }

  /**
   * 全屏相机层
   * 相机预览铺满整个屏幕，按钮和文字悬浮在画面上方
   */
  /**
   * 全屏相机层
   * 相机预览铺满屏幕，顶部和底部控件作为悬浮 HUD 显示
   */
  @Builder
  private buildCameraOverlay(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 最底层：全屏相机预览
      XComponent({
        id: 'gesture-camera-preview',
        type: XComponentType.SURFACE,
        controller: this.xComponentController
      })
        .onLoad(async () => {
          await this.handleSurfaceLoaded()
        })
        .onDestroy(() => {
          this.safeStopCamera()
        })
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')

      // 2. 顶层 HUD：一个全屏 Column，负责稳定排版
      Column() {
        // 顶部区域
        Column({ space: 10 }) {
          Row({ space: 12 }) {
            Text(this.chineseName ? this.chineseName : '手势训练')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Blank()

            Button('关闭')
              .height(40)
              .padding({ left: 18, right: 18 })
              .fontSize(16)
              .fontColor('#FFFFFF')
              .backgroundColor('rgba(0,0,0,0.38)')
              .borderRadius(20)
              .onClick(async () => {
                await this.closeCameraOverlay()
              })
          }
          .width('100%')

          Text(this.cameraStatusText)
            .fontSize(13)
            .fontColor('rgba(255,255,255,0.92)')
            .backgroundColor('rgba(0,0,0,0.28)')
            .borderRadius(14)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: 16,
          right: 16,
          top: this.getOverlayTopPadding(),
          bottom: 0
        })

        Blank()

        // 底部区域
        Column({ space: 12 }) {
          Text(this.previewStarted ? '预览已启动' : '等待预览启动')
            .fontSize(13)
            .fontColor('rgba(255,255,255,0.84)')
            .backgroundColor('rgba(0,0,0,0.24)')
            .borderRadius(14)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })

          Button('开始识别')
            .width('100%')
            .height(54)
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor('rgba(255,255,255,0.22)')
            .borderRadius(27)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({
          left: 16,
          right: 16,
          top: 0,
          bottom: this.getOverlayBottomPadding()
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  build() {
    Stack() {
      // 正常页面
      Column() {
        this.buildTopBar()

        Column() {
          Button('打开相机')
            .width('72%')
            .height(52)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .borderRadius(26)
            .onClick(async () => {
              await this.openCameraOverlay()
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')

      // 真全屏相机覆盖层
      if (this.showCameraOverlay) {
        this.buildCameraOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }
}