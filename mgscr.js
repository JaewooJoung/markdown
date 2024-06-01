document.addEventListener('DOMContentLoaded', function () {
  mermaid.initialize({
    startOnLoad: true,
    securityLevel: 'loose',
    gantt: {
      titleTopMargin: 25,
      barHeight: 20,
      barGap: 5,
      topPadding: 75,
      rightPadding: 75,
      leftPadding: 75,
      gridLineStartPadding: 10,
      fontSize: 12,
      sectionFontSize: 24,
      numberSectionStyles: 2,
      axisFormat: '%d/%m',
      tickInterval: '1 week',
      topAxis: true,
      displayMode: 'compact',
      weekday: 'sunday',
    },
  });
});
