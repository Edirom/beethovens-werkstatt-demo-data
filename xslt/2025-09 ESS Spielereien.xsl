<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:mei="http://www.music-encoding.org/ns/mei"
    exclude-result-prefixes="xs mei"
    version="3.0">
    
    <xsl:output method="xml" indent="yes"/>
    
    <!-- start template -->
    <xsl:template match="/">
        <xsl:apply-templates select="node()"/>    
    </xsl:template>
    
    <!-- specific templates go here -->
    <!-- am Ausgangsort löschen -->
    <xsl:template match="mei:layer/mei:*[@staff]"/>
    
    <!-- am Zielort einfügen -->
    <xsl:template match="mei:section">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
            <xsl:copy-of select=".//mei:layer/mei:*[@staff]"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- copy template -->
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    
</xsl:stylesheet>