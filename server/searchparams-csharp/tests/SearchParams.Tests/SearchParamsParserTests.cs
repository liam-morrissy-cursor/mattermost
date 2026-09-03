// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

namespace SearchParams.Tests;

public class SearchParamsParserTests
{
    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Parse_EmptyOrWhitespace_ReturnsEmpty(string? text)
    {
        var result = SearchParamsParser.Parse(text!, timeZoneOffset: 0);

        Assert.Empty(result);
    }

    [Fact]
    public void Parse_PlainText_ReturnsSingleTermsResult()
    {
        var result = SearchParamsParser.Parse("  hello  ", timeZoneOffset: -28800);

        Assert.Single(result);
        Assert.Equal("hello", result[0].Terms);
        Assert.Equal(-28800, result[0].TimeZoneOffset);
    }
}
