# react-native-mlkit-chinese-ocr

[![npm version](https://badge.fury.io/js/react-native-mlkit-chinese-ocr.svg)](https://badge.fury.io/js/react-native-mlkit-chinese-ocr)

Google on-device MLKit text recognition for React Native

此依赖基于 [https://github.com/agoldis/react-native-mlkit-ocr](https://github.com/agoldis/react-native-mlkit-ocr) 0.3.0 调整

## 安装

```sh
npm install react-native-mlkit-chinese-ocr
```

## Post-install

### iOS

Run

```js
cd ios && pod install
```

## 使用

```js
import MlkitOcr from 'react-native-mlkit-chinese-ocr';

// ...

const resultFromUri = await MlkitOcr.detectFromUri(uri);
const resultFromFile = await MlkitOcr.detectFromFile(path);
```

## License

MIT
