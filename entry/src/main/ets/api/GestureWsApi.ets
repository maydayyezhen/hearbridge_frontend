import { webSocket } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { AppConfig } from '../common/constants/AppConfig'
import { GestureWsResultMessage, GestureWsStartMessage } from '../model/GestureWsModels'

type OnResultCallback = (result: GestureWsResultMessage) => void
type OnErrorCallback = (message: string) => void
type OnCloseCallback = () => void

/**
 * 手势识别 WebSocket API。
 *
 * 只负责实时识别：
 * connect → start → send jpeg frame → receive result。
 */
export class GestureWsApi {
  private socket: webSocket.WebSocket | null = null
  private connected: boolean = false
  private started: boolean = false
  private openResolved: boolean = false
  private pendingConnectResolve: ((value: boolean) => void) | null = null

  private onResultCallback: OnResultCallback | null = null
  private onErrorCallback: OnErrorCallback | null = null
  private onCloseCallback: OnCloseCallback | null = null

  async connect(
    onResult: OnResultCallback,
    onError: OnErrorCallback,
    onClose: OnCloseCallback
  ): Promise<boolean> {
    if (this.connected && this.socket !== null) {
      console.info('[GestureWsApi] connect: already connected')
      return true
    }

    this.onResultCallback = onResult
    this.onErrorCallback = onError
    this.onCloseCallback = onClose

    this.socket = webSocket.createWebSocket()
    this.connected = false
    this.started = false
    this.openResolved = false
    this.bindSocketEvents()

    return await new Promise<boolean>((resolve) => {
      if (this.socket === null) {
        resolve(false)
        return
      }

      this.pendingConnectResolve = resolve

      console.info(`[GestureWsApi] connecting to ${AppConfig.GESTURE_WS_URL}`)
      this.socket.connect(AppConfig.GESTURE_WS_URL, (err: BusinessError, value: boolean) => {
        if (err) {
          console.error(`[GestureWsApi] connect callback error: ${JSON.stringify(err)}`)
          this.connected = false
          this.started = false
          this.emitError(`连接失败：${JSON.stringify(err)}`)
          if (this.pendingConnectResolve !== null) {
            this.pendingConnectResolve(false)
            this.pendingConnectResolve = null
          }
          return
        }

        console.info(`[GestureWsApi] connect callback success, value=${JSON.stringify(value)}`)
      })
    })
  }

  async startSession(width: number, height: number, fps: number): Promise<boolean> {
    if (!this.connected || !this.openResolved) {
      console.warn('[GestureWsApi] startSession ignored because socket is not opened')
      return false
    }

    const message = new GestureWsStartMessage(width, height, fps)
    const success = await this.sendRaw(JSON.stringify(message))
    if (success) {
      this.started = true
    }
    return success
  }

  async sendFrame(frameBytes: ArrayBuffer): Promise<boolean> {
    if (!this.connected || !this.started || frameBytes.byteLength <= 0) {
      return false
    }
    return await this.sendRaw(frameBytes)
  }

  async disconnect(): Promise<void> {
    this.started = false
    this.connected = false
    this.openResolved = false

    if (this.socket === null) {
      return
    }

    const currentSocket = this.socket
    this.socket = null

    await new Promise<void>((resolve) => {
      currentSocket.close((_: BusinessError, __: Object) => {
        resolve()
      })
    })
  }

  isConnected(): boolean {
    return this.connected
  }

  isStarted(): boolean {
    return this.started
  }

  private bindSocketEvents(): void {
    if (this.socket === null) {
      return
    }

    this.socket.on('open', (err: BusinessError, value: Object) => {
      if (err) {
        console.error(`[GestureWsApi] open error: ${JSON.stringify(err)}`)
        this.connected = false
        if (this.pendingConnectResolve !== null) {
          this.pendingConnectResolve(false)
          this.pendingConnectResolve = null
        }
        return
      }

      console.info(`[GestureWsApi] open event: ${JSON.stringify(value)}`)
      this.connected = true
      this.openResolved = true

      if (this.pendingConnectResolve !== null) {
        this.pendingConnectResolve(true)
        this.pendingConnectResolve = null
      }
    })

    this.socket.on('message', (err: BusinessError, value: string | ArrayBuffer) => {
      if (err) {
        this.emitError(`接收消息失败：${JSON.stringify(err)}`)
        return
      }

      if (typeof value === 'string') {
        this.handleTextMessage(value)
      }
    })

    this.socket.on('close', (_err: BusinessError, value: Object) => {
      console.warn(`[GestureWsApi] close: ${JSON.stringify(value)}`)
      this.connected = false
      this.started = false
      this.openResolved = false
      if (this.onCloseCallback !== null) {
        this.onCloseCallback()
      }
    })

    this.socket.on('error', (err: BusinessError) => {
      console.error(`[GestureWsApi] socket error: ${JSON.stringify(err)}`)
      this.connected = false
      this.started = false
      this.openResolved = false
      this.emitError(`WebSocket 异常：${JSON.stringify(err)}`)
    })
  }

  private handleTextMessage(text: string): void {
    try {
      const parsed = JSON.parse(text) as Record<string, Object>
      console.info(`[GestureWsApi] raw result text: ${text}`)
      const msgType = this.readStringField(parsed, 'type')

      if (msgType === 'result') {
        const result: GestureWsResultMessage = {
          type: msgType,
          status: this.readStringField(parsed, 'status'),
          label: this.readStringField(parsed, 'label'),
          confidence: this.readNumberField(parsed, 'confidence'),
          validFrames: this.readNumberField(parsed, 'validFrames'),
          windowSize: this.readNumberField(parsed, 'windowSize'),
          hasValidHand: this.readBooleanField(parsed, 'hasValidHand'),
          modelVersionName: this.readStringField(parsed, 'modelVersionName'),
          modelPath: this.readStringField(parsed, 'modelPath'),
          labelMapPath: this.readStringField(parsed, 'labelMapPath'),
          usingPublishedModel: this.readBooleanField(parsed, 'usingPublishedModel')
        }

        console.warn(
          `[HB_MODEL_VERSION][api] modelVersionName=${result.modelVersionName}, usingPublishedModel=${result.usingPublishedModel}`
        )

        if (this.onResultCallback !== null) {
          this.onResultCallback(result)
        }
        return
      }

      if (msgType === 'error') {
        const message = this.readStringField(parsed, 'message')
        this.emitError(message.length > 0 ? message : '识别服务返回错误')
        return
      }

      this.emitError(`未知消息类型：${msgType}`)
    } catch (parseError) {
      this.emitError(`解析服务端消息失败：${JSON.stringify(parseError)}`)
    }
  }

  private readStringField(source: Record<string, Object>, key: string): string {
    const value = source[key]
    if (typeof value === 'string') {
      return value
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      return String(value)
    }
    return ''
  }

  private readNumberField(source: Record<string, Object>, key: string): number {
    const value = source[key]
    if (typeof value === 'number') {
      return Number.isFinite(value) ? value : 0
    }
    if (typeof value === 'string' && value.trim().length > 0) {
      const parsed = Number(value)
      return Number.isFinite(parsed) ? parsed : 0
    }
    return 0
  }

  private readBooleanField(source: Record<string, Object>, key: string): boolean {
    const value = source[key]
    if (typeof value === 'boolean') {
      return value
    }
    if (typeof value === 'string') {
      return value === 'true'
    }
    return false
  }

  private async sendRaw(data: string | ArrayBuffer): Promise<boolean> {
    if (this.socket === null || !this.connected || !this.openResolved) {
      return false
    }

    return await new Promise<boolean>((resolve) => {
      if (this.socket === null) {
        resolve(false)
        return
      }

      this.socket.send(data, (err: BusinessError, value: boolean) => {
        if (err) {
          this.emitError(`发送失败：${JSON.stringify(err)}`)
          resolve(false)
          return
        }

        resolve(Boolean(value))
      })
    })
  }

  private emitError(message: string): void {
    if (this.onErrorCallback !== null) {
      this.onErrorCallback(message)
    }
  }
}