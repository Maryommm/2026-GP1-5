export interface RateLimitBinding {
  limit(options: { key: string }): Promise<{ success: boolean }>;
}

export interface Env {
  CLOUDINARY_CLOUD_NAME: string;
  CLOUDINARY_API_KEY: string;
  CLOUDINARY_API_SECRET: string;
  FIREBASE_PROJECT_ID: string;
  PROFILE_IMAGE_RATE_LIMITER: RateLimitBinding;
}

export interface AuthenticatedUser {
  uid: string;
  emailVerified: true;
}

export type SupportedImageType = "image/jpeg" | "image/png" | "image/webp";

export interface ValidatedImage {
  bytes: Uint8Array;
  mediaType: SupportedImageType;
  extension: "jpg" | "png" | "webp";
}

export interface UploadedProfileImage {
  publicId: string;
  secureUrl: string;
  version: number;
  format: string;
  width: number;
  height: number;
  bytes: number;
}

export interface DeletedProfileImage {
  publicId: string;
  deleted: boolean;
  notFound: boolean;
}

// A growth photo is stored and described like a profile image.
export type UploadedGrowthPhoto = UploadedProfileImage;
export type DeletedGrowthPhoto = DeletedProfileImage;

export interface DeletedPlantGrowthPhotos {
  deleted: number;
}

export interface WorkerDependencies {
  verifyToken(token: string, env: Env): Promise<AuthenticatedUser>;
  uploadProfileImage(
    env: Env,
    uid: string,
    image: ValidatedImage,
  ): Promise<UploadedProfileImage>;
  deleteProfileImage(env: Env, uid: string): Promise<DeletedProfileImage>;
  uploadGrowthPhoto(
    env: Env,
    uid: string,
    plantId: string,
    entryId: string,
    image: ValidatedImage,
  ): Promise<UploadedGrowthPhoto>;
  deleteGrowthPhoto(
    env: Env,
    uid: string,
    plantId: string,
    entryId: string,
  ): Promise<DeletedGrowthPhoto>;
  deletePlantGrowthPhotos(
    env: Env,
    uid: string,
    plantId: string,
  ): Promise<DeletedPlantGrowthPhotos>;
}
