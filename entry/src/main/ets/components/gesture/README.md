# gesture 组件目录

本目录用于存放手语练习相关的纯 UI 组件。

当前拆分目标是逐步减小 `GesturePracticePage.ets` 的体积，避免一个页面同时承担 UI、相机、识别、采集、数字人控制等过多职责。

## 约定

1. 本目录组件优先只负责展示和交互回调，不直接管理相机、WebSocket、数据采集等底层流程。
2. 相机生命周期、抓帧、识别会话、采集会话暂时仍保留在 `GesturePracticePage.ets` 中。
3. 后续如果继续重构，再逐步抽出 service 层，例如：
    - GestureFrameCaptureService
    - GestureRecognitionSessionService
    - DatasetCollectSessionService
4. 开发者 raw dataset 采集能力只应在开发者模式开启时显示，普通用户默认不暴露。