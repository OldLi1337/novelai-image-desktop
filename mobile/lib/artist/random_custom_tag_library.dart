// GENERATED FILE — edit shared/random-custom-tag-library.json, then run
// npm run generate:random-tags. Keeping this as Dart constants avoids a visible
// asynchronous asset-loading state when the mobile page opens.

class RandomCustomTagEntry {
  const RandomCustomTagEntry({required this.tag, required this.labels});

  final String tag;
  final Map<String, String> labels;

  String label(String language) => labels[language] ?? labels['zh-CN'] ?? tag;
}

class RandomCustomTagCategory {
  const RandomCustomTagCategory({
    required this.id,
    required this.labels,
    required this.tags,
  });

  final String id;
  final Map<String, String> labels;
  final List<RandomCustomTagEntry> tags;

  String label(String language) => labels[language] ?? labels['zh-CN'] ?? id;
}

const randomCustomTagLibrary = <RandomCustomTagCategory>[
  RandomCustomTagCategory(
    id: 'quality',
    labels: <String, String>{'zh-CN': '通用质量词'},
    tags: <RandomCustomTagEntry>[
      RandomCustomTagEntry(
          tag: 'masterpiece', labels: <String, String>{'zh-CN': '杰作级'}),
      RandomCustomTagEntry(
          tag: 'top aesthetic', labels: <String, String>{'zh-CN': '顶级美感（V4+）'}),
      RandomCustomTagEntry(
          tag: 'very aesthetic', labels: <String, String>{'zh-CN': '高美感'}),
      RandomCustomTagEntry(
          tag: 'aesthetic', labels: <String, String>{'zh-CN': '美感'}),
      RandomCustomTagEntry(
          tag: 'best quality', labels: <String, String>{'zh-CN': '最高质量'}),
      RandomCustomTagEntry(
          tag: 'amazing quality', labels: <String, String>{'zh-CN': '惊艳质量'}),
      RandomCustomTagEntry(
          tag: 'great quality', labels: <String, String>{'zh-CN': '优秀质量'}),
      RandomCustomTagEntry(
          tag: 'high quality', labels: <String, String>{'zh-CN': '高质量'}),
      RandomCustomTagEntry(
          tag: 'normal quality', labels: <String, String>{'zh-CN': '普通质量'}),
      RandomCustomTagEntry(
          tag: 'bad quality', labels: <String, String>{'zh-CN': '低质量（实验）'}),
      RandomCustomTagEntry(
          tag: 'worst quality', labels: <String, String>{'zh-CN': '最差质量（实验）'}),
      RandomCustomTagEntry(
          tag: 'absurdres', labels: <String, String>{'zh-CN': '超高分辨率'}),
      RandomCustomTagEntry(
          tag: 'highres', labels: <String, String>{'zh-CN': '高分辨率'}),
      RandomCustomTagEntry(
          tag: 'ultra detailed', labels: <String, String>{'zh-CN': '超精细'}),
      RandomCustomTagEntry(
          tag: 'extremely detailed', labels: <String, String>{'zh-CN': '极致细节'}),
      RandomCustomTagEntry(
          tag: 'intricate details', labels: <String, String>{'zh-CN': '繁复细节'}),
      RandomCustomTagEntry(
          tag: 'no text', labels: <String, String>{'zh-CN': '无文字'}),
      RandomCustomTagEntry(
          tag: 'low complexity', labels: <String, String>{'zh-CN': '低复杂度（V5）'}),
      RandomCustomTagEntry(
          tag: 'medium complexity',
          labels: <String, String>{'zh-CN': '中等复杂度（V5）'}),
      RandomCustomTagEntry(
          tag: 'high complexity',
          labels: <String, String>{'zh-CN': '高复杂度（V5）'}),
      RandomCustomTagEntry(
          tag: 'ultra complexity',
          labels: <String, String>{'zh-CN': '超高复杂度（V5）'}),
      RandomCustomTagEntry(
          tag: 'year 2026', labels: <String, String>{'zh-CN': '2026 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2025', labels: <String, String>{'zh-CN': '2025 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2024', labels: <String, String>{'zh-CN': '2024 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2023', labels: <String, String>{'zh-CN': '2023 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2022', labels: <String, String>{'zh-CN': '2022 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2021', labels: <String, String>{'zh-CN': '2021 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2020', labels: <String, String>{'zh-CN': '2020 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2019', labels: <String, String>{'zh-CN': '2019 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2018', labels: <String, String>{'zh-CN': '2018 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2017', labels: <String, String>{'zh-CN': '2017 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2016', labels: <String, String>{'zh-CN': '2016 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2015', labels: <String, String>{'zh-CN': '2015 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2014', labels: <String, String>{'zh-CN': '2014 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2013', labels: <String, String>{'zh-CN': '2013 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2012', labels: <String, String>{'zh-CN': '2012 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2011', labels: <String, String>{'zh-CN': '2011 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2010', labels: <String, String>{'zh-CN': '2010 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2009', labels: <String, String>{'zh-CN': '2009 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2008', labels: <String, String>{'zh-CN': '2008 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2007', labels: <String, String>{'zh-CN': '2007 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2006', labels: <String, String>{'zh-CN': '2006 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2005', labels: <String, String>{'zh-CN': '2005 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2004', labels: <String, String>{'zh-CN': '2004 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2003', labels: <String, String>{'zh-CN': '2003 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2002', labels: <String, String>{'zh-CN': '2002 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2001', labels: <String, String>{'zh-CN': '2001 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 2000', labels: <String, String>{'zh-CN': '2000 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1999', labels: <String, String>{'zh-CN': '1999 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1998', labels: <String, String>{'zh-CN': '1998 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1997', labels: <String, String>{'zh-CN': '1997 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1996', labels: <String, String>{'zh-CN': '1996 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1995', labels: <String, String>{'zh-CN': '1995 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1994', labels: <String, String>{'zh-CN': '1994 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1993', labels: <String, String>{'zh-CN': '1993 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1992', labels: <String, String>{'zh-CN': '1992 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1991', labels: <String, String>{'zh-CN': '1991 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1990', labels: <String, String>{'zh-CN': '1990 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1989', labels: <String, String>{'zh-CN': '1989 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1988', labels: <String, String>{'zh-CN': '1988 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1987', labels: <String, String>{'zh-CN': '1987 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1986', labels: <String, String>{'zh-CN': '1986 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1985', labels: <String, String>{'zh-CN': '1985 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1984', labels: <String, String>{'zh-CN': '1984 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1983', labels: <String, String>{'zh-CN': '1983 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1982', labels: <String, String>{'zh-CN': '1982 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1981', labels: <String, String>{'zh-CN': '1981 年画风'}),
      RandomCustomTagEntry(
          tag: 'year 1980', labels: <String, String>{'zh-CN': '1980 年画风'}),
    ],
  ),
  RandomCustomTagCategory(
    id: 'render3d',
    labels: <String, String>{'zh-CN': '3D 与渲染'},
    tags: <RandomCustomTagEntry>[
      RandomCustomTagEntry(
          tag: '3d', labels: <String, String>{'zh-CN': '3D 立体'}),
      RandomCustomTagEntry(
          tag: '3d render', labels: <String, String>{'zh-CN': '3D 渲染'}),
      RandomCustomTagEntry(
          tag: 'cgi', labels: <String, String>{'zh-CN': '计算机图形'}),
      RandomCustomTagEntry(
          tag: 'photorealistic', labels: <String, String>{'zh-CN': '照片级写实'}),
      RandomCustomTagEntry(
          tag: 'octane render',
          labels: <String, String>{'zh-CN': 'Octane 渲染质感'}),
      RandomCustomTagEntry(
          tag: 'unreal engine', labels: <String, String>{'zh-CN': '虚幻引擎质感'}),
      RandomCustomTagEntry(
          tag: 'blender', labels: <String, String>{'zh-CN': 'Blender 渲染'}),
      RandomCustomTagEntry(
          tag: 'ray tracing', labels: <String, String>{'zh-CN': '光线追踪'}),
      RandomCustomTagEntry(
          tag: 'physically based rendering',
          labels: <String, String>{'zh-CN': '基于物理的渲染'}),
      RandomCustomTagEntry(
          tag: 'subsurface scattering',
          labels: <String, String>{'zh-CN': '次表面散射'}),
    ],
  ),
  RandomCustomTagCategory(
    id: 'medium',
    labels: <String, String>{'zh-CN': '媒介与画法'},
    tags: <RandomCustomTagEntry>[
      RandomCustomTagEntry(
          tag: 'illustration', labels: <String, String>{'zh-CN': '插画'}),
      RandomCustomTagEntry(
          tag: 'digital painting', labels: <String, String>{'zh-CN': '数字绘画'}),
      RandomCustomTagEntry(
          tag: 'concept art', labels: <String, String>{'zh-CN': '概念设计'}),
      RandomCustomTagEntry(
          tag: 'anime coloring', labels: <String, String>{'zh-CN': '动画式上色'}),
      RandomCustomTagEntry(
          tag: 'painterly', labels: <String, String>{'zh-CN': '绘画笔触感'}),
      RandomCustomTagEntry(
          tag: 'watercolor', labels: <String, String>{'zh-CN': '水彩'}),
      RandomCustomTagEntry(
          tag: 'oil painting', labels: <String, String>{'zh-CN': '油画'}),
      RandomCustomTagEntry(
          tag: 'gouache', labels: <String, String>{'zh-CN': '水粉'}),
      RandomCustomTagEntry(
          tag: 'cel shading', labels: <String, String>{'zh-CN': '赛璐璐上色'}),
      RandomCustomTagEntry(
          tag: 'lineart', labels: <String, String>{'zh-CN': '线稿'}),
    ],
  ),
  RandomCustomTagCategory(
    id: 'lighting',
    labels: <String, String>{'zh-CN': '光影与照明'},
    tags: <RandomCustomTagEntry>[
      RandomCustomTagEntry(
          tag: 'cinematic lighting', labels: <String, String>{'zh-CN': '电影光影'}),
      RandomCustomTagEntry(
          tag: 'volumetric lighting', labels: <String, String>{'zh-CN': '体积光'}),
      RandomCustomTagEntry(
          tag: 'rim lighting', labels: <String, String>{'zh-CN': '轮廓光'}),
      RandomCustomTagEntry(
          tag: 'backlighting', labels: <String, String>{'zh-CN': '逆光'}),
      RandomCustomTagEntry(
          tag: 'side lighting', labels: <String, String>{'zh-CN': '侧光'}),
      RandomCustomTagEntry(
          tag: 'soft lighting', labels: <String, String>{'zh-CN': '柔和光线'}),
      RandomCustomTagEntry(
          tag: 'hard lighting', labels: <String, String>{'zh-CN': '硬朗光线'}),
      RandomCustomTagEntry(
          tag: 'dramatic lighting', labels: <String, String>{'zh-CN': '戏剧性光影'}),
      RandomCustomTagEntry(
          tag: 'studio lighting', labels: <String, String>{'zh-CN': '摄影棚灯光'}),
      RandomCustomTagEntry(
          tag: 'neon lighting', labels: <String, String>{'zh-CN': '霓虹灯光'}),
    ],
  ),
  RandomCustomTagCategory(
    id: 'color',
    labels: <String, String>{'zh-CN': '色彩与调色'},
    tags: <RandomCustomTagEntry>[
      RandomCustomTagEntry(
          tag: 'vibrant colors', labels: <String, String>{'zh-CN': '鲜艳色彩'}),
      RandomCustomTagEntry(
          tag: 'pastel colors', labels: <String, String>{'zh-CN': '粉彩色调'}),
      RandomCustomTagEntry(
          tag: 'muted colors', labels: <String, String>{'zh-CN': '低饱和色彩'}),
      RandomCustomTagEntry(
          tag: 'monochrome', labels: <String, String>{'zh-CN': '单色画面'}),
      RandomCustomTagEntry(
          tag: 'limited palette', labels: <String, String>{'zh-CN': '限制色板'}),
      RandomCustomTagEntry(
          tag: 'complementary colors',
          labels: <String, String>{'zh-CN': '互补色'}),
      RandomCustomTagEntry(
          tag: 'warm colors', labels: <String, String>{'zh-CN': '暖色调'}),
      RandomCustomTagEntry(
          tag: 'cool colors', labels: <String, String>{'zh-CN': '冷色调'}),
      RandomCustomTagEntry(
          tag: 'color contrast', labels: <String, String>{'zh-CN': '色彩对比'}),
      RandomCustomTagEntry(
          tag: 'iridescent colors', labels: <String, String>{'zh-CN': '虹彩色泽'}),
    ],
  ),
  RandomCustomTagCategory(
    id: 'texture',
    labels: <String, String>{'zh-CN': '材质与纹理'},
    tags: <RandomCustomTagEntry>[
      RandomCustomTagEntry(
          tag: 'detailed skin', labels: <String, String>{'zh-CN': '皮肤细节'}),
      RandomCustomTagEntry(
          tag: 'detailed eyes', labels: <String, String>{'zh-CN': '眼睛细节'}),
      RandomCustomTagEntry(
          tag: 'detailed hair', labels: <String, String>{'zh-CN': '发丝细节'}),
      RandomCustomTagEntry(
          tag: 'fabric texture', labels: <String, String>{'zh-CN': '布料纹理'}),
      RandomCustomTagEntry(
          tag: 'metallic texture', labels: <String, String>{'zh-CN': '金属质感'}),
      RandomCustomTagEntry(
          tag: 'glass texture', labels: <String, String>{'zh-CN': '玻璃质感'}),
      RandomCustomTagEntry(
          tag: 'wet surface', labels: <String, String>{'zh-CN': '湿润表面'}),
      RandomCustomTagEntry(
          tag: 'reflections', labels: <String, String>{'zh-CN': '反射质感'}),
      RandomCustomTagEntry(
          tag: 'glossy', labels: <String, String>{'zh-CN': '高光泽'}),
      RandomCustomTagEntry(
          tag: 'matte', labels: <String, String>{'zh-CN': '哑光质感'}),
    ],
  ),
  RandomCustomTagCategory(
    id: 'stylization',
    labels: <String, String>{'zh-CN': '风格化方向'},
    tags: <RandomCustomTagEntry>[
      RandomCustomTagEntry(
          tag: 'realistic', labels: <String, String>{'zh-CN': '写实'}),
      RandomCustomTagEntry(
          tag: 'semi-realistic', labels: <String, String>{'zh-CN': '半写实'}),
      RandomCustomTagEntry(
          tag: 'stylized', labels: <String, String>{'zh-CN': '强风格化'}),
      RandomCustomTagEntry(
          tag: 'anime style', labels: <String, String>{'zh-CN': '动漫风格'}),
      RandomCustomTagEntry(
          tag: 'manga style', labels: <String, String>{'zh-CN': '漫画风格'}),
      RandomCustomTagEntry(
          tag: 'chibi', labels: <String, String>{'zh-CN': 'Q 版比例'}),
      RandomCustomTagEntry(
          tag: 'minimalist', labels: <String, String>{'zh-CN': '极简主义'}),
      RandomCustomTagEntry(
          tag: 'maximalist', labels: <String, String>{'zh-CN': '极繁主义'}),
      RandomCustomTagEntry(
          tag: 'art nouveau', labels: <String, String>{'zh-CN': '新艺术风格'}),
      RandomCustomTagEntry(
          tag: 'futuristic', labels: <String, String>{'zh-CN': '未来主义'}),
    ],
  ),
];

final randomCustomTagValues = randomCustomTagLibrary
    .expand((category) => category.tags)
    .map((entry) => entry.tag.toLowerCase())
    .toSet();

int get randomCustomTagCount => randomCustomTagLibrary.fold(
      0,
      (total, category) => total + category.tags.length,
    );

bool matchesRandomCustomTagSearch(
  RandomCustomTagCategory category,
  RandomCustomTagEntry entry,
  String language,
  String query,
) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  final haystack = <String>[
    entry.tag,
    ...entry.labels.values,
    category.id,
    ...category.labels.values,
    entry.label(language),
  ].join('\n').toLowerCase();
  return haystack.contains(needle);
}
