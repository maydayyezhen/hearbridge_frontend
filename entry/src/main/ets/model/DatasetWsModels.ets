/**
 * 手机端 raw dataset 采集启动消息。
 */
export class DatasetWsStartMessage {
  type: string
  label: string
  fps: number
  windowSize: number
  format: string

  constructor(label: string, fps: number, windowSize: number) {
    this.type = 'start_dataset'
    this.label = label
    this.fps = fps
    this.windowSize = windowSize
    this.format = 'jpeg'
  }
}

/**
 * 手机端 raw dataset 采集取消消息。
 */
export class DatasetWsCancelMessage {
  type: string = 'cancel_dataset'
}

/**
 * Python 采集服务返回的状态消息。
 */
export interface DatasetWsStatusMessage {
  type: string
  status: string
  label: string
  validFrames: number
  windowSize: number
  message: string
  path: string
}