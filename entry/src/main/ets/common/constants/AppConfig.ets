/**
 * 应用配置
 */
export class AppConfig {
  /**
   * Java 后端基础地址（分类、手势列表等）
   */
  static readonly BASE_URL: string = 'http://192.168.43.6:8080'

  /**
   * Python 手势识别 WebSocket 地址
   * 这里填运行 MySssb 的电脑局域网 IP，不要写 127.0.0.1
   */
  static readonly GESTURE_WS_URL: string = 'ws://192.168.43.6:8000/ws/gesture'
}