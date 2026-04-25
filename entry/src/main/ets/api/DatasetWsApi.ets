import { webSocket } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { AppConfig } from '../common/constants/AppConfig'
import {
  DatasetWsCancelMessage,
  DatasetWsDiscardMessage,
  DatasetWsSaveMessage,
  DatasetWsStartMessage,
  DatasetWsStatusMessage
} from '../model/DatasetWsModels'

type OnDatasetStatusCallback = (message: DatasetWsStatusMessage) => void
type OnDatasetErrorCallback = (message: string) => void
type OnDatasetCloseCallback = () => void

/**
 * 手机端 raw dataset 采集 WebSocket API。
 */
export class DatasetWsApi {
  private socket: webSocket.WebSocket | null = null
  private connected: boolean = false
  private openResolved: boolean = false
  private pendingConnectResolve: ((value: boolean) => void) | null = null

  private onStatusCallback: OnDatasetStatusCallback | null = null
  private onErrorCallback: OnDatasetErrorCallback | null = null
  private onCloseCallback: OnDatasetCloseCallback | null = null

  async connect(
    onStatus: OnDatasetStatusCallback,
    onError: OnDatasetErrorCallback,
    onClose: OnDatasetCloseCallback
  ): Promise<boolean> {
    if (this.connected && this.socket !== null) {
      return true
    }

    this.onStatusCallback = onStatus
    this.onErrorCallback = onError
    this.onCloseCallback = onClose

    this.socket = webSocket.createWebSocket()
    this.connected = false
    this.openResolved = false
    this.bindSocketEvents()

    return await new Promise<boolean>((resolve) => {
      if (this.socket === null) {
        resolve(false)
        return
      }

      this.pendingConnectResolve = resolve
      this.socket.connect(AppConfig.DATASET_WS_URL, (err: BusinessError, _value: boolean) => {
        if (err) {
          this.connected = false
          this.emitError(`采集服务连接失败：${JSON.stringify(err)}`)
          if (this.pendingConnectResolve !== null) {
            this.pendingConnectResolve(false)
            this.pendingConnectResolve = null
          }
        }
      })
    })
  }

  async startDataset(label: string, fps: number, windowSize: number): Promise<boolean> {
    if (!this.connected || !this.openResolved) {
      return false
    }

    const message = new DatasetWsStartMessage(label, fps, windowSize)
    return await this.sendRaw(JSON.stringify(message))
  }

  async sendFrame(frameBytes: ArrayBuffer): Promise<boolean> {
    if (!this.connected || frameBytes.byteLength <= 0) {
      return false
    }
    return await this.sendRaw(frameBytes)
  }

  async cancelDataset(): Promise<boolean> {
    if (!this.connected || !this.openResolved) {
      return false
    }
    return await this.sendRaw(JSON.stringify(new DatasetWsCancelMessage()))
  }

  /**
   * 确认保存当前待确认样本。
   */
  async saveDataset(): Promise<boolean> {
    if (!this.connected || !this.openResolved) {
      return false
    }
    return await this.sendRaw(JSON.stringify(new DatasetWsSaveMessage()))
  }

  /**
   * 丢弃当前待确认样本。
   */
  async discardDataset(): Promise<boolean> {
    if (!this.connected || !this.openResolved) {
      return false
    }
    return await this.sendRaw(JSON.stringify(new DatasetWsDiscardMessage()))
  }

  async disconnect(): Promise<void> {
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

  private bindSocketEvents(): void {
    if (this.socket === null) {
      return
    }

    this.socket.on('open', (err: BusinessError, _value: Object) => {
      if (err) {
        this.connected = false
        if (this.pendingConnectResolve !== null) {
          this.pendingConnectResolve(false)
          this.pendingConnectResolve = null
        }
        return
      }

      this.connected = true
      this.openResolved = true

      if (this.pendingConnectResolve !== null) {
        this.pendingConnectResolve(true)
        this.pendingConnectResolve = null
      }
    })

    this.socket.on('message', (err: BusinessError, value: string | ArrayBuffer) => {
      if (err) {
        this.emitError(`接收采集状态失败：${JSON.stringify(err)}`)
        return
      }

      if (typeof value === 'string') {
        this.handleTextMessage(value)
      }
    })

    this.socket.on('close', (_err: BusinessError, _value: Object) => {
      this.connected = false
      this.openResolved = false
      if (this.onCloseCallback !== null) {
        this.onCloseCallback()
      }
    })

    this.socket.on('error', (err: BusinessError) => {
      this.connected = false
      this.openResolved = false
      this.emitError(`采集 WebSocket 异常：${JSON.stringify(err)}`)
    })
  }

  private handleTextMessage(text: string): void {
    try {
      const parsed = JSON.parse(text) as Record<string, Object>
      const msgType = this.readStringField(parsed, 'type')

      if (msgType === 'dataset_status') {
        const statusMessage: DatasetWsStatusMessage = {
          type: msgType,
          status: this.readStringField(parsed, 'status'),
          label: this.readStringField(parsed, 'label'),
          validFrames: this.readNumberField(parsed, 'validFrames'),
          windowSize: this.readNumberField(parsed, 'windowSize'),
          message: this.readStringField(parsed, 'message'),
          path: this.readStringField(parsed, 'path')
        }

        if (this.onStatusCallback !== null) {
          this.onStatusCallback(statusMessage)
        }
        return
      }

      if (msgType === 'dataset_error') {
        const message = this.readStringField(parsed, 'message')
        this.emitError(message.length > 0 ? message : '采集服务返回错误')
        return
      }

      this.emitError(`未知采集消息类型：${msgType}`)
    } catch (error) {
      this.emitError(`解析采集服务消息失败：${JSON.stringify(error)}`)
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
          this.emitError(`发送采集数据失败：${JSON.stringify(err)}`)
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