#import "state.typ": (
  ENTRY_CONTENT_FONT_SIZE_SCALE, ENTRY_DATE_FONT_SIZE_SCALE,
  ENTRY_LEFT_COLUMN_WIDTH, __st-theme,
)


/// Process a single author
///
/// -> content
#let __format-author(
  // author data
  author,
  pub_id,
) = {
  // in Hayagriva YAML, authors can be strings or dictionaries
  if (type(author) == dictionary) {
    author = (
      author.at("prefix", default: "")
        + " "
        + author.at("name", default: "")
        + ", "
        + author.at("given-name", default: "")
    ).trim()
  }

  assert(
    type(author) == str,
    message: "Author names must be strings or dictionaries.\nType:"
      + repr(type(author))
      + "\nEntry: "
      + pub_id
      + "\nFound: "
      + repr(author),
  )

  let author-parts = author.split(", ")
  let last-name = author-parts.at(0, default: author)
  let first-names-str = author-parts.at(1, default: "")

  if first-names-str == "" {
    return [#last-name]
  }

  let initials = first-names-str
    .split(" ")
    .filter(p => p.len() > 0)
    .map(p => [#p.at(0).])
    .join(" ")

  [#initials #last-name]
}

/// Formats a publication entry (article, conference, etc.).
///
/// -> content
#let __format-publication-entry(
  /// Publication data
  /// -> dictionary
  pub,
  /// Authors to highlight
  /// -> array
  highlight-authors,
  /// Max authors to display before "et al."
  /// -> int
  max-authors,
) = {
  // Make sure that author is an array
  if (type(pub.author) == str) {
    pub.author = (pub.author,)
  }

  for (i, author) in pub.author.enumerate() {
    if i < max-authors {
      let author-display = __format-author(author, pub.__id)

      if author in highlight-authors {
        text(weight: "medium", author-display)
      } else {
        author-display
      }

      if i < max-authors - 1 and i < pub.author.len() - 1 {
        if i == pub.author.len() - 2 {
          [, and ]
        } else {
          [, ]
        }
      }
    } else if i == max-authors {
      [, _et al_]
      break
    }
  }

  [, "#pub.title.replace(regex("[{}]"), "")",]

  // TODO: handle cases where parent is missing gracefully
  // at the moment we could assert its presence like this:
  // assert("parent" in pub,
  //     message: "Missing 'parent' field for publication:\n" +
  //     repr(pub) +
  //     "\nPlease ensure that the 'parent' field is provided.")
  // Alternative is to implement the Hayagriva spec more fully
  // Below is only a partial implementation

  if (not "parent" in pub) {
    if "publisher" in pub {
      [ _#pub.publisher.replace(regex("[{}]"), "")_]
    }
  } else {
    let parent = pub.parent

    if parent.type == "proceedings" {
      [ in ]
    }

    [ _#parent.title.replace(regex("[{}]"), "")_]

    if "volume" in parent and parent.volume != none {
      [ _#(parent.volume)_]
    }

    if "issue" in parent and parent.issue != none {
      [_(#parent.issue)_]
    }
  }

  if "page-range" in pub and pub.page-range != none {
    [_:#(pub.page-range)_]
  }

  if "date" in pub {
    [, #str(pub.date).split("-").at(0)]
  }

  if "serial-number" in pub and "doi" in pub.serial-number {
    [, doi: #link("https://doi.org/" + pub.serial-number.doi)[_#(pub.serial-number.doi)_]]
  }

  if "url" in pub and pub.url != none and type(pub.url) == str {
    [, #link(pub.url)[_#(pub.url)_]]
  }

  [.]
}

/// Displays publications for a specific year.
#let __format-publications-year(
  publications-year,
  /// Authors to highlight
  /// -> array
  highlight-authors,
  /// Max authors to display per entry
  /// -> int
  max-authors,
) = (
  for publication in publications-year {
    block([
      #set text(size: ENTRY_CONTENT_FONT_SIZE_SCALE * 1em)
      #__format-publication-entry(
        publication,
        highlight-authors,
        max-authors,
      )
    ])
  }
)

/// Displays publications grouped by year from a Hayagriva YAML file.
///
/// -> content
/// TODO: this should be handled by default bibliography support once it becomes more flexible,
/// so that for example different CLS citation styles can be used
#let publications(
  /// Data loaded from YAML file
  /// -> dictionary
  yaml-data,
  /// Authors to highlight
  /// -> array
  highlight-authors: (),
  /// Max authors to display per entry
  /// -> int
  max-authors: 10,
  /// Whether to display years in reverse order (most recent first)
  reverse-order: true,
) = (
  context {
    let theme = __st-theme.final()
    let publications-by-year = (:)

    set block(above: 0.7em, width: 100%)

    for (key, pub) in yaml-data {
      // add the ID to the publication data so we can better debug if needed
      pub.__id = key

      let year = str(pub.at("date", default: "")).split("-").at(0)

      // ignore publications without a date
      if year == "" {
        continue
      }

      if year in publications-by-year {
        publications-by-year.at(year) += (pub,)
      } else {
        publications-by-year.insert(year, (pub,))
      }
    }

    let all-years = publications-by-year.keys().sorted()

    if (reverse-order) {
      all-years = all-years.rev()
    }

    for year in all-years {
      grid(
        columns: (ENTRY_LEFT_COLUMN_WIDTH, auto),
        align: (right, left),
        column-gutter: .8em,
        text(
          size: ENTRY_DATE_FONT_SIZE_SCALE * 1em,
          fill: theme.font-color.lighten(50%),
          year,
        ),
        __format-publications-year(
          publications-by-year.at(year),
          highlight-authors,
          max-authors,
        ),
      )
    }
  }
)
