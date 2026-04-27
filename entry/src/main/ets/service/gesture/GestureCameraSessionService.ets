import { camera } from '@kit.CameraKit'
import { common } from '@kit.AbilityKit'
import { window, display } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl'

/**
 * 手语训练相机预览会话配置。
 */
export interface GestureCameraSessionConfig {
  /** 当前页面 Ability 上下文。 */
  context: common.UIAbilityContext
  /** XComponent 预览 Surface ID。 */
  surfaceId: string
  /** XComponent 控制器，用于同步 Surface 尺寸。 */
  xComponentController: XComponentController
  /** 相机预览真正开始时的回调。 */
  onFrameStart: () => void
  /** 相机预览异常回调。 */
  onPreviewError: (error: BusinessError) => void
}

/**
 * 手语训练相机预览会话启动结果。
 */
export interface GestureCameraSessionStartResult {
  /** 是否启动成功。 */
  success: boolean
  /** 页面可展示的状态文案。 */
  statusText: string
}

/**
 * 手语训练相机预览会话服务。
 *
 * 职责边界：
 * 1. 申请相机权限。
 * 2. 选择前置摄像头。
 * 3. 选择合适的预览 Profile。
 * 4. 创建 CameraInput / PreviewOutput / PhotoSession。
 * 5. 启动和释放相机预览。
 *
 * 不负责：
 * 1. 页面 UI。
 * 2. XComponent 生命周期。
 * 3. Surface 抓帧与 JPEG 编码。
 * 4. WebSocket 识别 / dataset 采集。
 */
export class GestureCameraSessionService {
  /** 相机管理器。 */
  private cameraManager?: camera.CameraManager

  /** 当前摄像头设备。 */
  private currentCamera?: camera.CameraDevice

  /** 当前相机输入。 */
  private currentCameraInput?: camera.CameraInput

  /** 当前预览输出。 */
  private currentPreviewOutput?: camera.PreviewOutput

  /** 当前拍照场景会话。 */
  private currentSession?: camera.PhotoSession

  /** 是否正在启动相机，避免重复启动。 */
  private starting: boolean = false

  /** 判断当前是否正在启动相机。 */
  isStarting(): boolean {
    return this.starting
  }

  /**
   * 申请相机权限。
   *
   * @param context 当前页面 Ability 上下文
   * @returns 是否授权成功
   */
  async requestCameraPermission(context: common.UIAbilityContext): Promise<boolean> {
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
      console.error(`[GestureCameraSessionService] request permission failed: code=${err.code}, message=${err.message}`)
      return false
    }
  }

  /**
   * 启动真实相机预览。
   *
   * @param config 相机预览启动配置
   * @returns 启动结果
   */
  async startPreview(config: GestureCameraSessionConfig): Promise<GestureCameraSessionStartResult> {
    if (this.starting) {
      return {
        success: false,
        statusText: '相机正在启动中'
      }
    }

    if (config.surfaceId.trim().length === 0) {
      return {
        success: false,
        statusText: '预览画面尚未就绪'
      }
    }

    this.starting = true

    try {
      const granted = await this.requestCameraPermission(config.context)
      if (!granted) {
        return {
          success: false,
          statusText: '未获得相机权限'
        }
      }

      await this.stopPreview()

      this.cameraManager = camera.getCameraManager(config.context)

      const cameraList: Array<camera.CameraDevice> = this.cameraManager.getSupportedCameras()
      if (!cameraList || cameraList.length === 0) {
        return {
          success: false,
          statusText: '未找到可用摄像头'
        }
      }

      this.currentCamera = this.pickCameraDevice(cameraList)
      if (!this.currentCamera) {
        return {
          success: false,
          statusText: '摄像头选择失败'
        }
      }

      const outputCapability: camera.CameraOutputCapability =
        this.cameraManager.getSupportedOutputCapability(this.currentCamera, camera.SceneMode.NORMAL_PHOTO)

      if (!outputCapability.previewProfiles || outputCapability.previewProfiles.length === 0) {
        return {
          success: false,
          statusText: '当前设备没有可用预览配置'
        }
      }

      const displayProfile = await this.pickBestPreviewProfile(config.context, outputCapability.previewProfiles)

      config.xComponentController.setXComponentSurfaceSize({
        surfaceWidth: displayProfile.size.width,
        surfaceHeight: displayProfile.size.height
      })

      this.currentCameraInput = this.cameraManager.createCameraInput(this.currentCamera)
      await this.currentCameraInput.open()

      this.currentPreviewOutput = this.cameraManager.createPreviewOutput(displayProfile, config.surfaceId)

      this.currentPreviewOutput.on('frameStart', () => {
        config.onFrameStart()
      })

      this.currentPreviewOutput.on('error', (previewError: BusinessError) => {
        config.onPreviewError(previewError)
      })

      this.currentSession = this.cameraManager.createSession(camera.SceneMode.NORMAL_PHOTO) as camera.PhotoSession
      this.currentSession.beginConfig()
      this.currentSession.addInput(this.currentCameraInput)
      this.currentSession.addOutput(this.currentPreviewOutput)
      await this.currentSession.commitConfig()

      const displayRotation = display.getDefaultDisplaySync().rotation * camera.ImageRotation.ROTATION_90
      const previewRotation = this.currentPreviewOutput.getPreviewRotation(displayRotation)
      this.currentPreviewOutput.setPreviewRotation(previewRotation, false)

      await this.currentSession.start()

      return {
        success: true,
        statusText: '正在启动预览'
      }
    } catch (error) {
      const err = error as BusinessError
      console.error(`[GestureCameraSessionService] start preview failed: code=${err.code}, message=${err.message}`)
      return {
        success: false,
        statusText: `相机启动失败：${err.code}`
      }
    } finally {
      this.starting = false
    }
  }

  /** 停止并释放相机预览。 */
  async stopPreview(): Promise<void> {
    try {
      if (this.currentSession) {
        await this.currentSession.stop()
      }
    } catch (error) {
      const err = error as BusinessError
      console.error(`[GestureCameraSessionService] stop session failed: code=${err.code}, message=${err.message}`)
    }

    try {
      if (this.currentPreviewOutput) {
        this.currentPreviewOutput.release()
      }
    } catch (error) {
      const err = error as BusinessError
      console.error(`[GestureCameraSessionService] release preview output failed: code=${err.code}, message=${err.message}`)
    }

    try {
      if (this.currentCameraInput) {
        this.currentCameraInput.close()
      }
    } catch (error) {
      const err = error as BusinessError
      console.error(`[GestureCameraSessionService] close camera input failed: code=${err.code}, message=${err.message}`)
    }

    this.currentSession = undefined
    this.currentPreviewOutput = undefined
    this.currentCameraInput = undefined
    this.currentCamera = undefined
    this.cameraManager = undefined
    this.starting = false
  }

  /**
   * 优先选择前置摄像头。
   *
   * @param cameraList 当前设备支持的摄像头列表
   * @returns 选中的摄像头
   */
  private pickCameraDevice(cameraList: Array<camera.CameraDevice>): camera.CameraDevice | undefined {
    if (!cameraList || cameraList.length === 0) {
      return undefined
    }

    for (let i = 0; i < cameraList.length; i += 1) {
      if (cameraList[i].cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT) {
        return cameraList[i]
      }
    }

    return cameraList[0]
  }

  /**
   * 获取预览 Profile 的竖屏宽高比。
   *
   * @param profile 预览 Profile
   * @returns 竖屏宽高比
   */
  private getPortraitRatioOfProfile(profile: camera.Profile): number {
    const width = profile.size.width
    const height = profile.size.height
    const shortSide = Math.min(width, height)
    const longSide = Math.max(width, height)
    return shortSide / longSide
  }

  /**
   * 根据当前窗口比例选择最合适的预览 Profile。
   *
   * @param context 当前页面 Ability 上下文
   * @param profiles 可用 Profile 列表
   * @returns 最合适的预览 Profile
   */
  private async pickBestPreviewProfile(
    context: common.UIAbilityContext,
    profiles: Array<camera.Profile>
  ): Promise<camera.Profile> {
    const win = await window.getLastWindow(context)
    const rect = win.getWindowProperties().windowRect
    const targetRatio = rect.width / rect.height

    let bestProfile = profiles[0]
    let bestDiff = Number.MAX_VALUE

    for (let i = 0; i < profiles.length; i += 1) {
      const currentRatio = this.getPortraitRatioOfProfile(profiles[i])
      const diff = Math.abs(currentRatio - targetRatio)
      if (diff < bestDiff) {
        bestDiff = diff
        bestProfile = profiles[i]
      }
    }

    return bestProfile
  }
}
