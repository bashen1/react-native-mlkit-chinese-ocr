import { NativeModules, Platform } from 'react-native';

const isIOS = Platform.OS === 'ios';
const isAndroid = Platform.OS === 'android';

// https://developers.google.com/ml-kit/reference/android

export type Point = {
  x: number;
  y: number;
};
/**
 * The four corner points of the text block / line / element in
 * clockwise order starting with the top left
 * point relative to the image in the default
 * coordinate space.
 **/
export type CornerPoints = Array<Point | null>;

/**
 * The rectangle that contains the text block / line / element
 * relative to the image in the default coordinate space.
 */
export type Bounding = {
  left: number;
  top: number;
  height: number;
  width: number;
};

/**
 * A text element recognized in an image.
 * A text element is roughly equivalent to
 * a space-separated word in most Latin-script languages.
 */
export type MLKTextElement = {
  text: string;
  cornerPoints: CornerPoints;
  bounding: Bounding;
};

/**
 *  A text line recognized in an image that consists of an array of elements.
 * */
export type MLKTextLine = {
  text: string;
  elements: Array<MLKTextElement>;
  cornerPoints: CornerPoints;
  bounding: Bounding;
};

/**
 * A text block recognized in an image that consists of an array of text lines.
 */
export type MKLBlock = {
  text: string;
  lines: MLKTextLine[];
  cornerPoints: CornerPoints;
  bounding: Bounding;
};

export type MlkitOcrResult = MKLBlock[];

type MlkitOcrAuthResult = {
  auth: boolean;
  code: number;
  message: string;
};

type MlkitOcrModule = {
  detectFromUri(uri: string): Promise<MlkitOcrResult>;
  detectFromFile(path: string): Promise<MlkitOcrResult>;
  checkAuth({}): Promise<MlkitOcrAuthResult>;
  requestAuth({}): Promise<MlkitOcrAuthResult>;
};

const MlkitOcr: MlkitOcrModule = NativeModules.MlkitOcr;

const MLKit: MlkitOcrModule = {
  detectFromUri: async (uri: string) => {
    const result = await MlkitOcr.detectFromUri(uri);
    if (!result) {
      return [];
    }
    return result;
  },
  detectFromFile: async (path: string) => {
    const result = await MlkitOcr.detectFromFile(path);
    if (!result) {
      return [];
    }
    return result;
  },
  checkAuth: async () => {
    const result = await MlkitOcr.checkAuth({});
    if (isAndroid) {
      return {
        auth: false,
        code: -1,
        message: 'Denied',
      };
    }
    return result;
  },
  requestAuth: async () => {
    const result = await MlkitOcr.requestAuth({});
    if (isAndroid) {
      return {
        auth: false,
        code: -1,
        message: 'Denied',
      };
    }
    return result;
  }
};

export default MLKit;
