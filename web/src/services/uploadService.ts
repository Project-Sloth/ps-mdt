/** Image compression settings (FiveM NUI has ~2MB packet limit) */
const MAX_IMAGE_WIDTH = 1280;
const MAX_IMAGE_HEIGHT = 1280;
const JPEG_QUALITY = 0.75;

/** Compress and resize an image, returns a base64 JPEG data URL */
export async function compressImage(file: File): Promise<string> {
	return new Promise((resolve, reject) => {
		const img = new Image();
		const url = URL.createObjectURL(file);

		img.onload = () => {
			URL.revokeObjectURL(url);

			let { width, height } = img;

			// Scale down if exceeds max dimensions
			if (width > MAX_IMAGE_WIDTH || height > MAX_IMAGE_HEIGHT) {
				const ratio = Math.min(
					MAX_IMAGE_WIDTH / width,
					MAX_IMAGE_HEIGHT / height,
				);
				width = Math.round(width * ratio);
				height = Math.round(height * ratio);
			}

			const canvas = document.createElement("canvas");
			canvas.width = width;
			canvas.height = height;

			const ctx = canvas.getContext("2d");
			if (!ctx) {
				reject(new Error("Failed to get canvas context"));
				return;
			}

			ctx.drawImage(img, 0, 0, width, height);

			// Convert to JPEG for smaller size (PNG screenshots can be huge)
			const dataUrl = canvas.toDataURL("image/jpeg", JPEG_QUALITY);
			canvas.width = 0;
			canvas.height = 0;

			resolve(dataUrl);
		};

		img.onerror = () => {
			URL.revokeObjectURL(url);
			reject(new Error("Failed to load image for compression"));
		};

		img.src = url;
	});
}

/** Convert a File to base64 data URL without compression */
export async function fileToBase64(file: File): Promise<string> {
	return new Promise((resolve, reject) => {
		const reader = new FileReader();
		reader.onload = () => resolve(reader.result as string);
		reader.onerror = () => reject(reader.error);
		reader.readAsDataURL(file);
	});
}

export function formatBytes(bytes: number): string {
	if (bytes === 0) return "0 B";
	const k = 1024;
	const sizes = ["B", "KB", "MB", "GB"];
	const i = Math.floor(Math.log(bytes) / Math.log(k));
	return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`;
}
