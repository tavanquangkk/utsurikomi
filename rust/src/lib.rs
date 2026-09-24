use ab_glyph::{Font, FontRef, PxScale, ScaleFont};
use image::{codecs::jpeg::JpegEncoder, GenericImageView, ImageBuffer, Rgb, RgbImage, Rgba};
use rayon::prelude::*;
use std::ffi::CStr;
use std::os::raw::c_char;
use std::slice;

const FONT_DATA: &[u8] = include_bytes!("../assets/fonts/DejaVuSans.ttf");

fn get_exif_orientation(bytes: &[u8]) -> u32 {
    if bytes.len() < 12 || bytes[0] != 0xFF || bytes[1] != 0xD8 {
        return 1;
    }
    let mut i = 2;
    while i + 4 < bytes.len() {
        if bytes[i] != 0xFF {
            i += 1;
            continue;
        }
        let marker = bytes[i + 1];
        if marker == 0xDA || marker == 0xD9 {
            break;
        }
        let len = ((bytes[i + 2] as usize) << 8) | (bytes[i + 3] as usize);
        if marker == 0xE1 && i + 14 < bytes.len() && &bytes[i + 4..i + 8] == b"Exif" {
            let tiff_start = i + 10;
            if tiff_start + 8 < bytes.len() {
                let is_le = &bytes[tiff_start..tiff_start + 2] == b"II";
                let get_u16 = |idx: usize| -> u16 {
                    if idx + 2 > bytes.len() { return 1; }
                    if is_le {
                        (bytes[idx] as u16) | ((bytes[idx + 1] as u16) << 8)
                    } else {
                        ((bytes[idx] as u16) << 8) | (bytes[idx + 1] as u16)
                    }
                };
                let get_u32 = |idx: usize| -> u32 {
                    if idx + 4 > bytes.len() { return 0; }
                    if is_le {
                        (bytes[idx] as u32) | ((bytes[idx + 1] as u32) << 8) | ((bytes[idx + 2] as u32) << 16) | ((bytes[idx + 3] as u32) << 24)
                    } else {
                        ((bytes[idx] as u32) << 24) | ((bytes[idx + 1] as u32) << 16) | ((bytes[idx + 2] as u32) << 8) | (bytes[idx + 3] as u32)
                    }
                };
                let ifd_offset = get_u32(tiff_start + 4) as usize;
                let ifd = tiff_start + ifd_offset;
                if ifd + 2 < bytes.len() {
                    let num_entries = get_u16(ifd) as usize;
                    for e in 0..num_entries {
                        let entry_ptr = ifd + 2 + e * 12;
                        if entry_ptr + 12 <= bytes.len() {
                            let tag = get_u16(entry_ptr);
                            if tag == 0x0112 {
                                return get_u16(entry_ptr + 8) as u32;
                            }
                        }
                    }
                }
            }
        }
        i += 2 + len;
    }
    1
}

#[inline(always)]
fn lookup_lut(data: &[f32], size: usize, r: u8, g: u8, b: u8) -> (u8, u8, u8) {
    if size < 2 {
        return (r, g, b);
    }
    let size_f = (size - 1) as f32;
    let rf = (r as f32 / 255.0) * size_f;
    let gf = (g as f32 / 255.0) * size_f;
    let bf = (b as f32 / 255.0) * size_f;

    let r0 = (rf.floor() as usize).min(size - 1);
    let g0 = (gf.floor() as usize).min(size - 1);
    let b0 = (bf.floor() as usize).min(size - 1);

    let r1 = (r0 + 1).min(size - 1);
    let g1 = (g0 + 1).min(size - 1);
    let b1 = (b0 + 1).min(size - 1);

    let dr = rf - r0 as f32;
    let dg = gf - g0 as f32;
    let db = bf - b0 as f32;

    let sample = |ri: usize, gi: usize, bi: usize, ch: usize| -> f32 {
        let idx = ((bi * size + gi) * size + ri) * 3 + ch;
        data.get(idx).copied().unwrap_or(0.0)
    };

    let interp = |ch: usize| -> u8 {
        let c000 = sample(r0, g0, b0, ch);
        let c100 = sample(r1, g0, b0, ch);
        let c010 = sample(r0, g1, b0, ch);
        let c110 = sample(r1, g1, b0, ch);
        let c001 = sample(r0, g0, b1, ch);
        let c101 = sample(r1, g0, b1, ch);
        let c011 = sample(r0, g1, b1, ch);
        let c111 = sample(r1, g1, b1, ch);

        let c00 = c000 * (1.0 - dr) + c100 * dr;
        let c10 = c010 * (1.0 - dr) + c110 * dr;
        let c01 = c001 * (1.0 - dr) + c101 * dr;
        let c11 = c011 * (1.0 - dr) + c111 * dr;

        let c0 = c00 * (1.0 - dg) + c10 * dg;
        let c1 = c01 * (1.0 - dg) + c11 * dg;

        let val = (c0 * (1.0 - db) + c1 * db) * 255.0;
        (val.round() as i32).clamp(0, 255) as u8
    };

    (interp(0), interp(1), interp(2))
}

#[inline(always)]
fn grain_noise(x: u32, y: u32) -> i32 {
    let mut value = ((x as u64).wrapping_mul(374761393).wrapping_add((y as u64).wrapping_mul(668265263))) & 0x7fffffff;
    value = ((value ^ (value >> 13)).wrapping_mul(1274126177)) & 0x7fffffff;
    ((value % 33) as i32) - 16
}

/// Native C interface for high-performance image processing.
#[no_mangle]
pub extern "C" fn process_image_native(
    src_ptr: *const u8,
    src_len: usize,
    lut_ptr: *const f32,
    lut_len: usize,
    lut_size: i32,
    apply_filter: bool,
    grain_amount: i32,
    frame_index: i32,
    note_text_ptr: *const c_char,
    note_date_ptr: *const c_char,
    note_font_size: i32,
    frame_thickness: i32,
    exposure: f32,
    contrast: f32,
    warmth: f32,
    vignette: f32,
    max_dimension: i32,
    out_len: *mut usize,
) -> *mut u8 {
    if src_ptr.is_null() || src_len == 0 || out_len.is_null() {
        return std::ptr::null_mut();
    }

    let src_slice = unsafe { slice::from_raw_parts(src_ptr, src_len) };
    let lut_data = if !lut_ptr.is_null() && lut_len > 0 {
        unsafe { slice::from_raw_parts(lut_ptr, lut_len) }
    } else {
        &[]
    };

    let note_text = if !note_text_ptr.is_null() {
        unsafe { CStr::from_ptr(note_text_ptr).to_string_lossy().to_string() }
    } else {
        String::new()
    };

    let note_date = if !note_date_ptr.is_null() {
        unsafe { CStr::from_ptr(note_date_ptr).to_string_lossy().to_string() }
    } else {
        String::new()
    };

    // Decode image using fast native decoder
    let mut dynamic_img = match image::load_from_memory(src_slice) {
        Ok(img) => img,
        Err(_) => return std::ptr::null_mut(),
    };

    // Correct EXIF orientation (Rotate image pixels so orientation matches display)
    let orientation = get_exif_orientation(src_slice);
    match orientation {
        3 => dynamic_img = dynamic_img.rotate180(),
        6 => dynamic_img = dynamic_img.rotate90(),
        8 => dynamic_img = dynamic_img.rotate270(),
        _ => {}
    }

    // Resize if max_dimension is specified and exceeded
    if max_dimension > 0 {
        let (w, h) = dynamic_img.dimensions();
        let max_dim = max_dimension as u32;
        if w > max_dim || h > max_dim {
            dynamic_img = dynamic_img.resize(max_dim, max_dim, image::imageops::FilterType::Triangle);
        }
    }

    let mut rgb_img = dynamic_img.to_rgb8();
    let (width, height) = rgb_img.dimensions();

    // Pre-calculate adjustment constants
    let exp_mult = (2.0f32).powf(exposure);
    let contrast_factor = 1.0 + contrast;
    let warmth_shift = warmth * 25.0;
    let cx = width as f32 / 2.0;
    let cy = height as f32 / 2.0;
    let max_radius_sq = cx * cx + cy * cy;

    let needs_adjustments = exposure != 0.0 || contrast != 0.0 || warmth != 0.0 || vignette > 0.0;
    let needs_pixel_pass = apply_filter || grain_amount > 0 || needs_adjustments;

    if needs_pixel_pass {
        let lut_sz = lut_size as usize;
        let apply_f = apply_filter && lut_sz >= 2 && !lut_data.is_empty();

        let row_stride = (width * 3) as usize;
        let raw_pixels = rgb_img.as_mut();

        raw_pixels
            .par_chunks_exact_mut(row_stride)
            .enumerate()
            .for_each(|(y, row)| {
                let py = y as f32 - cy;
                for (x_idx, pixel_chunk) in row.chunks_exact_mut(3).enumerate() {
                    let px = x_idx as f32 - cx;
                    let r = pixel_chunk[0];
                    let g = pixel_chunk[1];
                    let b = pixel_chunk[2];

                    let (mut nr, mut ng, mut nb) = if apply_f {
                        lookup_lut(lut_data, lut_sz, r, g, b)
                    } else {
                        (r, g, b)
                    };

                    // Exposure & Contrast & Warmth & Vignette
                    if needs_adjustments {
                        let mut rf = nr as f32;
                        let mut gf = ng as f32;
                        let mut bf = nb as f32;

                        if exposure != 0.0 {
                            rf *= exp_mult;
                            gf *= exp_mult;
                            bf *= exp_mult;
                        }

                        if contrast != 0.0 {
                            rf = 128.0 + contrast_factor * (rf - 128.0);
                            gf = 128.0 + contrast_factor * (gf - 128.0);
                            bf = 128.0 + contrast_factor * (bf - 128.0);
                        }

                        if warmth != 0.0 {
                            rf += warmth_shift;
                            bf -= warmth_shift;
                        }

                        if vignette > 0.0 {
                            let dist_sq = px * px + py * py;
                            let norm_dist = (dist_sq / max_radius_sq).min(1.0);
                            let vig_mult = 1.0 - (vignette * norm_dist * 0.6).min(0.85);
                            rf *= vig_mult;
                            gf *= vig_mult;
                            bf *= vig_mult;
                        }

                        nr = (rf.round() as i32).clamp(0, 255) as u8;
                        ng = (gf.round() as i32).clamp(0, 255) as u8;
                        nb = (bf.round() as i32).clamp(0, 255) as u8;
                    }

                    if grain_amount > 0 {
                        let noise = grain_noise(x_idx as u32, y as u32);
                        let delta = noise * grain_amount / 16;
                        nr = (nr as i32 + delta).clamp(0, 255) as u8;
                        ng = (ng as i32 + delta).clamp(0, 255) as u8;
                        nb = (nb as i32 + delta).clamp(0, 255) as u8;
                    }

                    pixel_chunk[0] = nr;
                    pixel_chunk[1] = ng;
                    pixel_chunk[2] = nb;
                }
            });
    }

    // Frame and Note Composition
    let final_img = add_frame_and_note(
        &rgb_img,
        frame_index,
        &note_text,
        &note_date,
        note_font_size,
        frame_thickness,
    );

    // Encode to JPEG
    let mut out_bytes: Vec<u8> = Vec::with_capacity(final_img.len());
    let mut encoder = JpegEncoder::new_with_quality(&mut out_bytes, 95);
    if encoder.encode_image(&final_img).is_err() {
        return std::ptr::null_mut();
    }

    unsafe {
        *out_len = out_bytes.len();
    }

    let mut boxed_slice = out_bytes.into_boxed_slice();
    let ptr = boxed_slice.as_mut_ptr();
    std::mem::forget(boxed_slice);

    ptr
}

#[no_mangle]
pub extern "C" fn free_native_buffer(ptr: *mut u8, len: usize) {
    if !ptr.is_null() && len > 0 {
        unsafe {
            let _ = Vec::from_raw_parts(ptr, len, len);
        }
    }
}

fn add_frame_and_note(
    img: &RgbImage,
    frame_index: i32,
    note_text: &str,
    note_date: &str,
    note_font_size: i32,
    frame_thickness: i32,
) -> RgbImage {
    let (w, h) = img.dimensions();
    let frame_style_none = frame_index == 0;
    if frame_style_none && note_text.is_empty() && note_date.is_empty() {
        return img.clone();
    }

    let shortest_side = w.min(h);
    let border = ((shortest_side as f32 * frame_thickness as f32 / 100.0).round() as u32).clamp(8, 240);

    let frame_color = if frame_index == 2 {
        Rgb([18, 18, 18]) // Black frame
    } else {
        Rgb([248, 246, 240]) // White frame
    };

    let note_color = if frame_index == 2 {
        Rgba([248, 246, 240, 255])
    } else {
        Rgba([18, 18, 18, 255])
    };

    let parts: Vec<&str> = [note_text, note_date]
        .iter()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .collect();
    let note = parts.join("  •  ");

    if note.is_empty() {
        let framed_w = w + border * 2;
        let framed_h = h + border * 2;
        let mut framed = ImageBuffer::from_pixel(framed_w, framed_h, frame_color);
        image::imageops::overlay(&mut framed, img, border as i64, border as i64);
        return framed;
    }

    // Render Text Note if provided
    let text_scale = note_font_size as f32 * shortest_side as f32 / (720.0 * 24.0);
    let font = FontRef::try_from_slice(FONT_DATA).ok();

    let base_font_size = (note_font_size as f32 * text_scale.max(0.5)).clamp(12.0, 72.0);
    let text_height = (base_font_size * 1.2).round().clamp(14.0, 240.0) as u32;
    let note_padding = ((shortest_side as f32 * 0.02).round() as u32).clamp(8, 48);
    let bottom_border = (text_height + note_padding).clamp(border, 240);

    let framed_w = w + border * 2;
    let framed_h = h + border + bottom_border;
    let mut framed = ImageBuffer::from_pixel(framed_w, framed_h, frame_color);
    image::imageops::overlay(&mut framed, img, border as i64, border as i64);

    if let Some(font) = font {
        let scale = PxScale::from(base_font_size);
        let scaled_font = font.as_scaled(scale);

        let mut total_width = 0.0f32;
        for c in note.chars() {
            let glyph_id = font.glyph_id(c);
            total_width += scaled_font.h_advance(glyph_id);
        }

        let start_x = if (framed_w as f32) > total_width {
            ((framed_w as f32 - total_width) / 2.0) as i64
        } else {
            border as i64
        };

        let start_y = (h + border + (bottom_border - text_height) / 2) as i64;

        let mut caret_x = start_x as f32;
        for c in note.chars() {
            let glyph_id = font.glyph_id(c);
            let glyph = glyph_id.with_scale_and_position(scale, ab_glyph::point(caret_x, start_y as f32 + scaled_font.ascent()));
            if let Some(outlined) = font.outline_glyph(glyph) {
                let bounds = outlined.px_bounds();
                outlined.draw(|x, y, v| {
                    let px = (bounds.min.x as i64 + x as i64) as u32;
                    let py = (bounds.min.y as i64 + y as i64) as u32;
                    if px < framed_w && py < framed_h {
                        let orig = framed.get_pixel(px, py);
                        let alpha = v;
                        let r = ((note_color[0] as f32 * alpha) + (orig[0] as f32 * (1.0 - alpha))) as u8;
                        let g = ((note_color[1] as f32 * alpha) + (orig[1] as f32 * (1.0 - alpha))) as u8;
                        let b = ((note_color[2] as f32 * alpha) + (orig[2] as f32 * (1.0 - alpha))) as u8;
                        framed.put_pixel(px, py, Rgb([r, g, b]));
                    }
                });
            }
            caret_x += scaled_font.h_advance(glyph_id);
        }
    }

    framed
}
