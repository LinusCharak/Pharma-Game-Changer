-- ============================================================
-- Demo Detailing videos (replaces the "videodetailing-default-rtdb"
-- Firebase project -- same data, migrated to Supabase for one
-- consistent backend). Run in Supabase SQL Editor.
-- ============================================================

create table demo_videos (
  id            bigint generated always as identity primary key,
  code          text not null unique,   -- original Firebase key, e.g. 'A1'
  title         text not null,
  thumbnail_url text not null,
  video_url     text not null,
  sort_order    int not null default 0,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

alter table demo_videos enable row level security;
create policy "read active demo videos" on demo_videos
  for select using (is_active = true);

-- Seed data, migrated 1:1 from videodetailing-default-rtdb-export.json
insert into demo_videos (code, title, thumbnail_url, video_url, sort_order) values
('A1', 'M2Tone AUB', 'https://res.cloudinary.com/linus4763/image/upload/v1759123306/VideoDetailing/Icon/M2tone_AUB1.jpg', 'https://res.cloudinary.com/linus4763/video/upload/v1682074273/VideoDetailing/VideoDetailing/M2tone_AUB.mp4', 1),
('A2', 'M2Tone Infertility', 'https://res.cloudinary.com/linus4763/image/upload/v1759123253/VideoDetailing/Icon/M2tone_Infertility1.jpg', 'https://res.cloudinary.com/linus4763/video/upload/v1682074264/VideoDetailing/VideoDetailing/M2tone_Infertility.mp4', 2),
('A3', 'M2Tone Forte', 'https://res.cloudinary.com/linus4763/image/upload/v1759123260/VideoDetailing/Icon/M2tone_forte1.jpg', 'https://res.cloudinary.com/linus4763/video/upload/v1682074242/VideoDetailing/VideoDetailing/M2tone_Forte.mp4', 3),
('A4', 'Livomyn GP/CP', 'https://res.cloudinary.com/linus4763/image/upload/v1759123964/VideoDetailing/Icon/Livomyn_GP1.jpg', 'https://res.cloudinary.com/linus4763/video/upload/v1682074132/VideoDetailing/VideoDetailing/Livomyn_GP.mp4', 4),
('A5', 'Livomyn Peadiatrician', 'https://res.cloudinary.com/linus4763/image/upload/v1759123964/VideoDetailing/Icon/Livomyn_DCH1.jpg', 'https://res.cloudinary.com/linus4763/video/upload/v1682074100/VideoDetailing/VideoDetailing/Livomyn_DCH.mp4', 5),
('A6', 'Livomyn Gyneacologist', 'https://res.cloudinary.com/linus4763/image/upload/v1759123963/VideoDetailing/Icon/Livomyn_DGO1.jpg', 'https://res.cloudinary.com/linus4763/video/upload/v1682074084/VideoDetailing/VideoDetailing/Livomyn_ICP.mp4', 6),
('A7', 'Livomyn Detailing', 'https://res.cloudinary.com/linus4763/image/upload/v1759120043/VideoDetailing/Icon/Liv_Thumbnail.jpg', 'https://res.cloudinary.com/linus4763/video/upload/v1759119685/VideoDetailing/VideoDetailing/Livomyn_Video.mp4', 7),
('A8', 'Manoll Detailing', 'https://res.cloudinary.com/linus4763/image/upload/v1759124288/VideoDetailing/Icon/Manoll2.jpg', 'https://res.cloudinary.com/linus4763/video/upload/v1681809204/VideoDetailing/VideoDetailing/Manoll_Final_Compressed.mp4', 8),
('A9', 'Hyponidd Detailing', 'https://res.cloudinary.com/linus4763/image/upload/v1759124514/VideoDetailing/Icon/Hyponidd_Icon1.jpg', 'https://res.cloudinary.com/linus4763/video/upload/v1682263816/VideoDetailing/VideoDetailing/Hyponidd_Compressed.mp4', 9),
('B1', 'Addyzoa Detailing', 'https://res.cloudinary.com/linus4763/image/upload/v1759124782/VideoDetailing/Icon/Addyzoa_Icon1.jpg', 'https://res.cloudinary.com/linus4763/video/upload/v1682263769/VideoDetailing/VideoDetailing/Addyzoa_Compressed.mp4', 10),
('B2', 'Calcury Detailing', 'https://res.cloudinary.com/linus4763/image/upload/v1759125085/VideoDetailing/Icon/Calcury_GP_Icon1.jpg', 'https://res.cloudinary.com/linus4763/video/upload/v1685427723/VideoDetailing/VideoDetailing/Calcury_compressed1.mp4', 11)
on conflict (code) do update set
  title = excluded.title,
  thumbnail_url = excluded.thumbnail_url,
  video_url = excluded.video_url,
  sort_order = excluded.sort_order;
