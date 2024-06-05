document.addEventListener('DOMContentLoaded', function () {
  mermaid.initialize({
    startOnLoad: true,
    securityLevel: 'loose',
    theme: 'default', // or 'base', 'forest', etc., depending on the theme you're using
    themeVariables: {
      ganttBarColor: '#f00', // Example: Sets the Gantt chart bars to red
      // Other theme variables can be set here as well
    },
    gantt: {
      titleTopMargin: 25,
      barHeight: 20,
      barGap: 10,
      topPadding: 75,
      rightPadding: 75,
      leftPadding: 75,
      gridLineStartPadding: 20,
      fontSize: 16,
      sectionFontSize: 24,
      numberSectionStyles: 2,
      axisFormat: '%d/%m',
      tickInterval: '1 week',
      topAxis: true,
      displayMode: 'compact',
      weekday: 'sunday',
      todayMarker: false, // 오늘 막대를 비활성화합니다.

    },
  });
});
