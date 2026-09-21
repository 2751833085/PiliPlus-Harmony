import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { MethodResult } from '@ohos/flutter_ohos';

// The native SaveButton grants a temporary media-library permission. Prepare
// resources before showing it, so encoding does not consume the grant lifetime.
export class MovingPhotoSave {
  private static pending: MethodResult | null = null;
  private static cover: ArrayBuffer | null = null;
  private static videoUri: string = '';
  private static saving: boolean = false;

  static async request(imagePath: string, videoPath: string, result: MethodResult): Promise<void> {
    if (MovingPhotoSave.pending !== null) {
      result.error('MOVING_PHOTO_BUSY', '另一张动态照片正在保存', null);
      return;
    }
    if (!imagePath.startsWith('/') || !videoPath.startsWith('/')) {
      result.error('MOVING_PHOTO_PATH', '动态照片文件路径无效', null);
      return;
    }
    MovingPhotoSave.pending = result;
    let source: image.ImageSource | null = null;
    let packer: image.ImagePacker | null = null;
    try {
      source = image.createImageSource(imagePath);
      packer = image.createImagePacker();
      // Bilibili covers can be WebP. A moving photo needs a supported still image.
      const cover = await packer.packing(source, { format: 'image/jpeg', quality: 95 });
      if (MovingPhotoSave.pending !== result) return;
      MovingPhotoSave.cover = cover;
      MovingPhotoSave.videoUri = fileUri.getUriFromPath(videoPath);
      AppStorage.setOrCreate('movingPhotoPreview', fileUri.getUriFromPath(imagePath));
      AppStorage.setOrCreate('movingPhotoSaveVisible', true);
    } catch (error) {
      if (MovingPhotoSave.pending === result) MovingPhotoSave.fail(error as BusinessError);
    } finally {
      await packer?.release();
      await source?.release();
    }
  }

  static async save(context: common.UIAbilityContext): Promise<void> {
    if (MovingPhotoSave.saving || MovingPhotoSave.pending === null || MovingPhotoSave.cover === null) return;
    const operation = MovingPhotoSave.pending;
    MovingPhotoSave.saving = true;
    AppStorage.setOrCreate('movingPhotoSaving', true);
    let helper: photoAccessHelper.PhotoAccessHelper | null = null;
    try {
      helper = photoAccessHelper.getPhotoAccessHelper(context);
      const request = photoAccessHelper.MediaAssetChangeRequest.createAssetRequest(
        context, photoAccessHelper.PhotoType.IMAGE, 'jpg', {
          title: `PiliPlus_${Date.now()}`,
          subtype: photoAccessHelper.PhotoSubtype.MOVING_PHOTO
        });
      request.addResource(photoAccessHelper.ResourceType.IMAGE_RESOURCE, MovingPhotoSave.cover);
      request.addResource(photoAccessHelper.ResourceType.VIDEO_RESOURCE, MovingPhotoSave.videoUri);
      await helper.applyChanges(request);
      if (MovingPhotoSave.pending === operation) MovingPhotoSave.finish(true);
    } catch (error) {
      if (MovingPhotoSave.pending === operation) MovingPhotoSave.fail(error as BusinessError);
    } finally {
      await helper?.release();
    }
  }

  static cancel(): void {
    if (!MovingPhotoSave.saving) MovingPhotoSave.finish(false);
  }

  static detach(): void {
    MovingPhotoSave.finish(false);
  }

  static denied(): void {
    const result = MovingPhotoSave.pending;
    MovingPhotoSave.clear();
    result?.error('MOVING_PHOTO_PERMISSION', '未获得保存动态照片的授权，请重试', null);
  }

  private static fail(error: BusinessError): void {
    const result = MovingPhotoSave.pending;
    MovingPhotoSave.clear();
    result?.error('MOVING_PHOTO_SAVE', `动态照片保存失败 (${error.code}): ${error.message}`, null);
  }

  private static finish(saved: boolean): void {
    const result = MovingPhotoSave.pending;
    MovingPhotoSave.clear();
    result?.success(saved);
  }

  private static clear(): void {
    MovingPhotoSave.pending = null;
    MovingPhotoSave.cover = null;
    MovingPhotoSave.videoUri = '';
    MovingPhotoSave.saving = false;
    AppStorage.setOrCreate('movingPhotoSaveVisible', false);
    AppStorage.setOrCreate('movingPhotoSaving', false);
    AppStorage.setOrCreate('movingPhotoPreview', '');
  }
}
